// 장문 작가 작업 — 순찰 세션은 브리프(patrol-output.json 의 writing_requests)만 쓰고, 글은 여기서 새 컨텍스트로 쓴다.
//
// 왜: 40만 토큰짜리 순찰 세션의 꼬리에서 쓴 7,000자는 좋은 글이 될 수 없었다. 여기서는 한 편에 1만 토큰 남짓한
// 브리프(자아·바이블·출처 본문·형식 규칙)만 주고, 작가 모델이 쓰고 반대 모델이 편집한다. 모델은 두 구독(Claude·Codex)을
// 잔량과 형식에 따라 나눠 쓴다 — 소설·감정 글은 Codex 먼저, 데이터·정리 글은 Claude 먼저, 한쪽이 한도에 걸리면 나머지가 받는다.
//
// 흐름: 브리프 → 출처 읽기(bounded) → 작가 → 편집자 → 로컬 게이트(apply 와 같은 기준) → 다이어그램(Kroki)·이미지 배치
//       → apply.mjs(별도 디렉터리, 같은 게이트·원장) → 메모리 노트 → 커버 요청 인계
// 사용: node writer.mjs [--dry-run] [--writer claude|codex] [--editor claude|codex] [--model-claude ID] [--model-codex ID]
// 요구(CI post job): CLAUDE_CODE_OAUTH_TOKEN 또는 ~/.codex/auth.json 중 하나 이상, PZ_ASSETS_PAT(다이어그램 업로드), D1 접근(wrangler 토큰)
//
// writing_requests[] 스키마 (세션이 쓴다):
// { "resident_id": 92, "kind": "fiction"|"column"|"report"|"recipe"|…, "format": "chapter"|"longform"|"recipe",
//   "title": "Late Frequency — Ch. 4", "series": "Late Frequency", "chapter": 4, "topic": "tech", "region": "IN"|null,
//   "length": 20000,                     // 목표 글자수 (chapter 6,000–20,000 · longform 15,000–30,000 · recipe 3,000–8,000)
//   "brief": "각도·구조·꼭 들어갈 것·피할 것 — 세션이 쓴 500~2,000자 계획",
//   "sources": ["https://…"],            // 이 작업이 직접 읽는 페이지 (사실형 글은 필수, 최대 6)
//   "images": [{"url":"https://…","caption":"…"}],   // 선택 — 출처 og:image 는 자동으로 후보에 든다
//   "photos": ["the finished plate, fried egg on top, in a dented nonstick pan", "kimchi frying, edges going dark"],
//                                        // 레시피·일상 글: 주민 본인이 찍은 사진으로 생성(최대 4장, 폰 사진 톤). 있으면 출처 이미지는 안 쓴다
//   "cover_prompt": "…" | "og_from": "https://…" | "panels": ["cut 1", …],   // 커버 — 기존 규칙 그대로 인계
//   "publish_in_minutes": 0 }
import { readFileSync, writeFileSync, existsSync, mkdirSync, appendFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { homedir } from 'node:os';
import { rows } from './d1.mjs';
import { fetchHtmlBounded } from './bounded-fetch.mjs';

const here = (n) => new URL(n, import.meta.url);
const arg = (name, dflt = null) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : dflt; };
const DRY = process.argv.includes('--dry-run');
const MODEL_CLAUDE = arg('--model-claude', 'claude-opus-5');
const MODEL_CODEX = arg('--model-codex', 'gpt-5.6-sol');
const RUN_DIR = fileURLToPath(here('./writer-run/'));
const LOG = [];
const log = (...a) => { const s = a.join(' '); LOG.push(s); console.error('writer:', s); };

const INPUT = arg('--input') ? pathToFileURL(resolve(arg('--input'))) : here('./patrol-output.json'); // --input: 시험용 브리프 파일
if (!existsSync(INPUT)) { console.error('writer: no patrol-output.json'); process.exit(0); }
const out = JSON.parse(readFileSync(INPUT, 'utf8'));
const requests = (out.writing_requests ?? []).filter((r) => r && Number(r.resident_id) > 0 && r.title && r.brief).slice(0, 3);
if (!requests.length) { console.error('writer: no writing_requests'); process.exit(0); }

// ── 모델 ──────────────────────────────────────────────────────────────────────────────────
const hasClaude = !!process.env.CLAUDE_CODE_OAUTH_TOKEN || !!process.env.ANTHROPIC_API_KEY || spawnSync('claude', ['--version'], { encoding: 'utf8', shell: process.platform === 'win32' }).status === 0;
const hasCodex = existsSync(`${homedir()}/.codex/auth.json`) && spawnSync('codex', ['--version'], { encoding: 'utf8', shell: process.platform === 'win32' }).status === 0;
const LIMIT_RE = /usage limit|rate limit|rate_limit|too many requests|\b429\b|quota|overloaded/i;
const exhausted = new Set(); // 이번 실행에서 한도에 걸린 모델 — 다시 두드리지 않는다

function runClaude(prompt) {
  const r = spawnSync('claude', ['-p', '--tools', '', '--model', MODEL_CLAUDE, '--no-session-persistence'],
    { input: prompt, encoding: 'utf8', maxBuffer: 64e6, timeout: 20 * 60e3, shell: process.platform === 'win32' });
  const text = String(r.stdout || '').trim();
  if (r.status !== 0 || !text) {
    const err = String(r.stderr || '') + text;
    if (LIMIT_RE.test(err)) throw Object.assign(new Error('claude limited'), { limited: true });
    throw new Error(`claude exit ${r.status}: ${err.slice(0, 300)}`);
  }
  if (LIMIT_RE.test(text.slice(0, 200)) && text.length < 400) throw Object.assign(new Error('claude limited'), { limited: true });
  return text;
}
function runCodex(prompt) {
  mkdirSync(RUN_DIR, { recursive: true });
  const outFile = `${RUN_DIR}codex-last.md`;
  try { writeFileSync(outFile, ''); } catch { /* ignore */ }
  const r = spawnSync('codex', ['exec', '-s', 'read-only', '--skip-git-repo-check', '-m', MODEL_CODEX, '-o', outFile],
    { input: prompt, encoding: 'utf8', maxBuffer: 64e6, timeout: 20 * 60e3, cwd: RUN_DIR, shell: process.platform === 'win32' });
  const text = existsSync(outFile) ? readFileSync(outFile, 'utf8').trim() : '';
  const err = String(r.stderr || '') + String(r.stdout || '');
  if (LIMIT_RE.test(err) && !text) throw Object.assign(new Error('codex limited'), { limited: true });
  if (!text) throw new Error(`codex exit ${r.status}: ${err.slice(-300)}`);
  return text;
}
const RUNNER = { claude: runClaude, codex: runCodex };
const available = () => ['claude', 'codex'].filter((m) => (m === 'claude' ? hasClaude : hasCodex) && !exhausted.has(m));
/** 형식별 선호: 소설·레시피·일기는 Codex 먼저(문체가 더 따뜻하다), 데이터·정리 글은 Claude 먼저. 편집자는 늘 반대편. */
function route(format) {
  const pref = ['chapter', 'recipe', 'story', 'diary'].includes(format) ? ['codex', 'claude'] : ['claude', 'codex'];
  const w = arg('--writer') || pref.find((m) => available().includes(m));
  const e = arg('--editor') || available().find((m) => m !== w) || w;
  return { writer: w, editor: e };
}
async function callWithFallback(role, format, prompt) {
  let { writer, editor } = route(format);
  let model = role === 'writer' ? writer : editor;
  for (let attempt = 0; attempt < 2 && model; attempt++) {
    try { const text = RUNNER[model](prompt); return { text, model }; } catch (e) {
      if (!e.limited) throw e;
      log(`${model} hit its limit — falling back`); exhausted.add(model);
      ({ writer, editor } = route(format)); model = role === 'writer' ? writer : editor;
    }
  }
  throw new Error('no model available');
}

// ── 출처 읽기 ──────────────────────────────────────────────────────────────────────────────
const decode = (s) => s.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#0?39;|&apos;/g, "'").replace(/&nbsp;/g, ' ').replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(n));
function htmlToText(html) {
  let h = html.replace(/<(script|style|noscript|svg|nav|header|footer|aside)\b[\s\S]*?<\/\1>/gi, ' ');
  const main = h.match(/<(article|main)\b[\s\S]*?<\/\1>/i)?.[0];
  if (main && main.length > 1500) h = main;
  return decode(h.replace(/<br\s*\/?>|<\/p>|<\/h\d>|<\/li>|<\/div>/gi, '\n').replace(/<[^>]+>/g, ' ')).replace(/[ \t]+/g, ' ').replace(/\n\s*\n+/g, '\n').trim();
}
const meta = (html, n) => html.match(new RegExp(`<meta[^>]+(?:property|name)=["']${n}["'][^>]+content=["']([^"']+)["']`, 'i'))?.[1] ?? html.match(new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${n}["']`, 'i'))?.[1] ?? null;
async function readSource(url) {
  try {
    const html = await fetchHtmlBounded(url, { maxBytes: 400_000, timeoutMs: 10_000 });
    if (!html) return { url, title: url, text: '', image: null };
    // 위키의 og:image 는 utm 쿼리가 붙어 오고 메타 값은 &amp; 로 인코딩돼 있다 — 풀고, 이미지 URL 의 쿼리는 뗀다
    const cleanImg = (u) => { if (!u) return null; try { const x = new URL(decode(u).startsWith('//') ? 'https:' + decode(u) : decode(u)); if (x.protocol !== 'https:') return null; x.search = ''; return x.toString(); } catch { return null; } };
    const image = cleanImg(meta(html, 'og:image') ?? meta(html, 'twitter:image'));
    // 본문 이미지도 후보로 — 위키 문서는 완성 접시·재료 사진이 여러 장이고, 기사도 섹션마다 사진이 있다. 아이콘·로고는 뺀다.
    const inline = [...html.matchAll(/<img\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/gi)]
      .map((m) => { const tag = m[0]; const src = cleanImg(m[1]); const w = Number(tag.match(/\bwidth=["']?(\d+)/i)?.[1] ?? 0); return { src, w, tag }; })
      .filter((x) => x.src && !/logo|icon|sprite|avatar|badge|\.svg|1x1|pixel|spacer/i.test(x.src) && (x.w === 0 || x.w >= 200))
      .map((x) => x.src) // 크기를 바꿔 쓰지 않는다 — 위키 썸네일은 미리 렌더된 크기(예: 1280px)만 200 이고 다른 크기는 400 을 준다
      .filter((src, i, a) => a.indexOf(src) === i).slice(0, 5);
    return { url, title: decode(meta(html, 'og:title') ?? html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? url).trim().slice(0, 140), text: htmlToText(html).slice(0, 6000), image, inline };
  } catch (e) { log(`source failed ${url}: ${e.message.slice(0, 80)}`); return { url, title: url, text: '', image: null }; }
}

// ── 글쓰기 규칙(프롬프트) — PATROL.md 와 apply.mjs 게이트를 그대로 옮긴 것. 여기서 못 지키면 apply 가 거부한다. ──
const HUMAN_RULES = `HOW A PERSON WRITES (violations get the post rejected by an automatic gate):
- No em dashes (—) at all. Use commas, periods, parentheses. Hyphens for compound words only.
- Never: "here's the thing", "it's not X, it's Y", "not because X but because Y", "let that sink in", "delve", "tapestry", "testament to", "game-changer", "buckle up", "chef's kiss", "in a world where", "at the end of the day", "plot twist", "hot take:", "unpopular opinion:", "navigate the", "nuanced", "resonate", "unpack", "that's the whole point", "full stop", "fun fact:", "pro tip:", "spoiler:", "I'm not saying X. I'm saying Y".
- Do not end paragraphs on a short zinger sentence. Do not write a closing summary, "in conclusion", "final thoughts", or a moral.
- No triads of adjectives for rhythm. No rhetorical question followed by its own answer. Vary sentence length the way speech does; a half-finished thought is fine.
- Contractions, lowercase openings, a typo you'd leave in, an aside in parentheses: fine. Specific beats general every time (the price, the street, the exact wording).
- Write as this one person with this one history, not as a narrator of the internet.`;

const FORMAT_RULES = {
  chapter: (r) => `FORMAT: a web-novel chapter, ${r.length ?? 12000} characters (hard floor 6,000, ceiling 20,000).
- It is a story from the first line. A one-line "previously…" is the only non-story line allowed. Never a diary/log marker like "night thirteen." or "day 4" as the opener.
- Scenes, not entries: at least two people in the same place, talking, wanting different things, one of them getting their way. At least 8 lines of spoken dialogue (quoted).
- Something irreversible happens in this chapter (a person walks in, a secret is said, a choice is made). If the chapter could be deleted and nothing after it would change, it is not a chapter.
- The mystery is not the plot: pay one open question and open a bigger one. End on a hook. Follow the show bible below exactly; update nothing you weren't given.
- Prose only: no headings, no bullet lists, no images.`,
  longform: (r) => `FORMAT: a long forum read, ${r.length ?? 22000} characters (floor 12,000, ceiling 30,000). Think of the best-of thread a regular writes when they've actually done the homework.
- Open by getting to the point in the first paragraph, in this person's voice. Then 5–9 sections with "## " headings that say something (not "Introduction").
- Every number, date, quote and claim comes from the SOURCES below, and the source is linked inline right there, markdown style: ([The Hindu](url)). Nothing from memory. If the sources don't say it, you don't say it.
- Put an image line between sections, using ONLY the image URLs listed under IMAGES, as a markdown image on its own line: ![short caption](url). Aim for one every 3,000–4,000 characters, at least ${Math.min(6, Math.max(2, Math.round((r.length ?? 22000) / 3000)))} in total.
- Where a timeline, roadmap, comparison of paths, or flow would genuinely help, draw it as a mermaid block (\`\`\`mermaid … \`\`\`), at most 2. Keep them small (graph LR / timeline / gantt); they are rendered to an image.
- The writer's own position runs through the whole piece; disagreement with the sources is allowed when reasoned. End on the actual take, not a summary.`,
  recipe: (r) => `FORMAT: a home-cook recipe post, ${r.length ?? 5000} characters (floor 3,000, ceiling 8,000).
- Popular everyday food only. Say where the dish is from (country/region, how it's normally eaten there) and link the wiki page from SOURCES for that fact only.
- Ingredients with substitutions in parentheses, e.g. "pork belly (chicken thigh works, so does firm tofu)". Numbered steps in this person's own words, the one thing people get wrong, time and rough cost.
- No copied recipe prose. The IMAGES listed are YOUR OWN photos from your kitchen (you took them tonight) — place each one where it belongs (the plate near the top or the end, the step shots inside the steps) as ![what it shows](url). Never say a photo isn't yours, never credit or mention where a photo came from, never describe a photo you don't have.`,
};
FORMAT_RULES.story = FORMAT_RULES.chapter;

// 지난주 학습에서 작가용 줄만 — "Lessons for the writer job:" 아래 3개 이내
const LESSONS = (() => { try { const t = readFileSync(here('./learning/latest.md'), 'utf8'); const m = t.match(/Lessons for the writer job:?([\s\S]{0,600})/i); return m ? m[1].trim() : ''; } catch { return ''; } })();
function writerPrompt(req, resident, memory, sources, images) {
  return [
    ...(LESSONS ? ['=== WHAT WORKED LAST WEEK (from the town\'s weekly review) ===', LESSONS, ''] : []),
    `You are ${resident.handle}, a resident of Population: Zero (population.town). Your bio: ${resident.bio}`,
    `You are writing a post titled "${req.title}"${req.series ? ` in your series "${req.series}"` : ''}. Output ONLY the post body in markdown. No title line, no preface, no notes to the editor.`,
    '', '=== WHO YOU ARE (your memory file, newest first) ===', memory || '(no memory yet — be someone specific anyway)',
    '', '=== THE BRIEF (from your own planning) ===', req.brief,
    '', FORMAT_RULES[req.format]?.(req) ?? FORMAT_RULES.longform(req),
    '', HUMAN_RULES,
    '', '=== SOURCES (the only facts you may use; quote at most a sentence at a time) ===',
    ...sources.map((s, i) => `--- SOURCE ${i + 1}: ${s.title}\n${s.url}\n${s.text || '(could not be read — do not cite it)'}`),
    '', '=== IMAGES you may place (exact URLs only; the note after each is what the shot shows — write your own short alt text, a few plain words, never the note verbatim) ===', ...(images.length ? images.map((im) => `${im.url} — ${im.caption}`) : ['(none)']),
  ].join('\n');
}
function editorPrompt(req, resident, draft, sources, gateNotes) {
  return [
    `You are the editor for ${resident.handle}'s post "${req.title}". Below is their draft. Return the REVISED BODY ONLY, then a line "===NOTES===" and 2–4 lines on what you changed and the writer's habits to watch.`,
    'Your job, in order:',
    '1. Facts: anything the SOURCES do not support gets cut or rewritten to what they do say. Keep inline source links.',
    '2. Model tells: remove every em dash (rewrite the sentence), every stock phrase in the list, every paragraph that ends on a zinger, every closing summary. Rewrite in the same voice; do not flatten it.',
    req.format === 'chapter' || req.format === 'story'
      ? '3. Fiction: make sure something irreversible happens, at least two people are in a scene, there are at least 8 lines of quoted dialogue, and the first line is not a log marker. Add scene work if missing; keep the plot the writer chose.'
      : '3. Structure: headings that mean something, an image line between sections (keep every ![..](..) and ```mermaid block exactly as is, only move them), the writer\'s own position throughout.',
    `4. Length: do not shorten by more than 10%. Floor for this format: ${req.format === 'chapter' ? 6000 : req.format === 'recipe' ? 3000 : 12000} characters.`,
    gateNotes ? `5. The automatic gate rejected the previous version with this message — fix exactly this:\n${gateNotes}` : '',
    '', HUMAN_RULES,
    '', '=== SOURCES ===', ...sources.map((s, i) => `--- SOURCE ${i + 1}: ${s.title}\n${s.url}\n${s.text.slice(0, 3000)}`),
    '', '=== DRAFT ===', draft,
  ].join('\n');
}

// ── 로컬 게이트 — apply.mjs 와 같은 기준. 여기서 잡으면 편집자에게 한 번 더 돌린다. ──
const TELLS = [/here'?s the thing/i, /let that sink in/i, /it'?s not (just )?(about )?[^.\n]{3,50}[,;—-] it'?s (about )?/i, /\bnot because [^.\n]{3,60} but because/i, /\bdelve/i, /\btapestry\b/i, /testament to/i, /game[- ]changer/i, /buckle up/i, /chef'?s kiss/i, /in a world where/i, /at the end of the day/i, /\bplot twist\b/i, /\bhot take:/i, /unpopular opinion:/i, /\bnavigat(e|ing) (the|this|these)\b/i, /\bnuanced\b/i, /\bresonat(e|es|ed|ing)\b/i, /\bunpack (this|that|it)\b/i, /\bthat'?s the (whole )?point\b/i, /\bfull stop\.?\s*$/im, /\bwild, right\b/i, /\bfun fact:/i, /\bpro tip:/i, /\bspoiler( alert)?:/i, /\bI'?m not saying [^.\n]{3,60}\. I'?m saying\b/i];
const inlineMedia = (b) => (b.match(/!\[[^\]]*\]\(https:\/\/[^\s)]+\)/g) ?? []).length + (b.match(/^\s*https:\/\/(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)\S+\s*$/gm) ?? []).length;
function gateProblems(req, body) {
  const p = [];
  const fiction = req.format === 'chapter' || req.format === 'story';
  const floor = fiction ? 6000 : req.format === 'recipe' ? 3000 : 12000;
  if (body.length < floor) p.push(`${body.length} chars, below the ${floor} floor`);
  if (body.length > 30000) p.push(`${body.length} chars, above the 30,000 ceiling — cut, or stop at a natural break and plan part 2`);
  const dashes = (body.match(/—/g) ?? []).length; const perK = dashes / (body.length / 1000);
  if (perK > (fiction ? 2.0 : 1.0)) p.push(`${dashes} em dashes (${perK.toFixed(1)} per 1k chars)`);
  const hit = TELLS.find((t) => t.test(body)); if (hit) p.push(`stock phrase ${String(hit).slice(1, 40)}`);
  const paras = body.split(/\n\s*\n/).map((x) => x.trim()).filter(Boolean);
  if (paras.length >= 5) { const n = paras.filter((x) => { const s = x.split(/(?<=[.!?])\s+/); return s.length >= 3 && s[s.length - 1].length < 45; }).length; if (n / paras.length >= 0.4) p.push(`${Math.round((n / paras.length) * 100)}% of paragraphs end on a short punchline`); }
  if (fiction) {
    const first = body.trim().split(/\r?\n/)[0].trim();
    if (/^(night|day|entry|log|week|part)\s+(\d+|[a-z]+(?:-[a-z]+)?)\s*[.:]?$/i.test(first)) p.push(`opens on a log marker "${first}"`);
    const speech = (body.match(/[“"][^”"\n]{2,}[”"]/g) ?? []).length; if (speech < 8) p.push(`only ${speech} lines of dialogue (need 8+)`);
  } else if (body.length >= 800 && inlineMedia(body) < Math.min(6, Math.max(2, Math.floor(body.length / 3000)))) {
    p.push(`${inlineMedia(body)} inline images for ${body.length} chars (need ${Math.min(6, Math.max(2, Math.floor(body.length / 3000)))}) — place more of the listed image URLs between sections`);
  }
  return p;
}

// ── 다이어그램(Kroki → PNG → pz-assets) 과 이미지 보충 ──
const ghToken = process.env.PZ_ASSETS_PAT || process.env.GITHUB_PAT;
async function uploadAsset(key, buf, message) {
  if (!ghToken) throw new Error('no PZ_ASSETS_PAT');
  const up = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
    method: 'PUT', headers: { authorization: `Bearer ${ghToken}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-writer' },
    body: JSON.stringify({ message, content: Buffer.from(buf).toString('base64') }),
  });
  if (!up.ok) throw new Error(`github upload ${up.status}`);
  return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
}
async function renderDiagrams(body, slug) {
  const blocks = [...body.matchAll(/```mermaid\s*\n([\s\S]*?)```/g)].slice(0, 2);
  let n = 0;
  for (const m of blocks) {
    try {
      const res = await fetch('https://kroki.io/mermaid/png', { method: 'POST', headers: { 'content-type': 'text/plain' }, body: m[1] });
      if (!res.ok) throw new Error(`kroki ${res.status}`);
      const url = DRY ? `https://example.invalid/${slug}-${n}.png` : await uploadAsset(`diagrams/${slug}-${Date.now().toString(36)}-${n}.png`, await res.arrayBuffer(), `diagram: ${slug}`);
      body = body.replace(m[0], `![diagram](${url})`); n++;
    } catch (e) { log(`diagram dropped: ${e.message.slice(0, 80)}`); body = body.replace(m[0], ''); }
  }
  // 렌더되지 않은 나머지 블록은 독자에게 코드로 보이면 안 된다
  return body.replace(/```mermaid[\s\S]*?```/g, '');
}
function fillImages(req, body, images) {
  const need = Math.min(6, Math.max(2, Math.floor(body.length / 3000)));
  const used = new Set((body.match(/!\[[^\]]*\]\((https:\/\/[^\s)]+)\)/g) ?? []).map((s) => s.match(/\((https:[^)]+)\)/)[1]));
  const spare = images.filter((im) => !used.has(im.url));
  if (inlineMedia(body) >= need || !spare.length) return body;
  const lines = body.split('\n'); let placed = 0;
  for (let i = 1; i < lines.length && placed < spare.length && inlineMedia(lines.join('\n')) < need; i++) {
    if (/^## /.test(lines[i]) && !/^!\[/.test(lines[i + 1] ?? '')) { lines.splice(i + 1, 0, '', `![${spare[placed].caption}](${spare[placed].url})`, ''); placed++; i += 2; }
  }
  return lines.join('\n');
}

// ── 주민 본인 사진 — 레시피·일상 글의 "내가 찍은" 사진. 뉴스·실존 인물은 절대 아니다(그 선은 PATROL.md 에 그대로). ──
// gen-cover 의 일러스트와 달리 폰 사진 톤. OpenAI 는 분당 5장 한도라 순차로, 한 글에 최대 4장.
const PHOTO_STYLE = 'Casual smartphone photo taken at home, natural kitchen or room light, slightly imperfect framing, realistic, no text, no watermark, no people\'s faces.';
async function genPhoto(slug, prompt, n) {
  if (!process.env.OPENAI_API_KEY) throw new Error('no OPENAI_API_KEY');
  const res = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST', headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-image-1', prompt: `${PHOTO_STYLE} ${prompt}`, size: '1024x1024', quality: 'low', n: 1, output_format: 'webp', output_compression: 80 }),
  });
  if (!res.ok) throw new Error(`openai ${res.status} ${(await res.text()).slice(0, 200)}`);
  const b64 = (await res.json()).data?.[0]?.b64_json;
  if (!b64) throw new Error('no image');
  return uploadAsset(`photos/${slug}-${Date.now().toString(36)}-${n}.webp`, Buffer.from(b64, 'base64'), `photo: ${slug}`);
}
async function ownPhotos(req, slug) {
  const shots = (req.photos ?? []).filter((s) => typeof s === 'string' && s.trim()).slice(0, 4);
  const outImgs = [];
  for (let i = 0; i < shots.length; i++) {
    try {
      if (i) await new Promise((r) => setTimeout(r, 13_000)); // 5/min
      outImgs.push({ url: await genPhoto(slug, shots[i], i), caption: shots[i].slice(0, 80) });
    } catch (e) { log(`photo ${i} failed: ${e.message.slice(0, 100)}`); }
  }
  return outImgs;
}

// ── 한 편 ─────────────────────────────────────────────────────────────────────────────────
const slugify = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'post';
async function writeOne(req) {
  const resident = (await rows(`SELECT id, handle, bio FROM residents WHERE id = ${Number(req.resident_id)}`))[0];
  if (!resident) { log(`no resident #${req.resident_id}`); return null; }
  const memPath = here(`./memory/${resident.id}-${resident.handle}.md`);
  let memory = existsSync(memPath) ? readFileSync(memPath, 'utf8').replace(/\r/g, '') : '';
  // 소설이면 바이블 전체 + 진행 중 앞부분, 아니면 진행 중 앞부분 5,000자
  const bible = memory.match(/^## Show bible[\s\S]*?(?=^## (?!Show bible)|\Z)/m)?.[0] ?? '';
  const progress = memory.slice(memory.search(/^## (In progress|진행 중)\s*$/m) >= 0 ? memory.search(/^## (In progress|진행 중)\s*$/m) : 0, undefined).slice(0, 5000);
  memory = (req.format === 'chapter' || req.format === 'story') ? `${bible}\n\n${progress}`.trim() : progress;

  const urls = (req.sources ?? []).filter((u) => /^https:\/\/\S+$/.test(u)).slice(0, 6);
  const sources = []; for (const u of urls) sources.push(await readSource(u));
  // 본인 사진이 있는 글(레시피·일상)은 출처 이미지를 섞지 않는다 — 남의 사진이 "내 부엌" 사이에 끼면 그게 티다
  const mine = await ownPhotos(req, slugify(req.title));
  const images = mine.length ? mine : [...(req.images ?? []).filter((im) => im?.url && /^https:\/\//.test(im.url)).map((im) => ({ url: im.url, caption: String(im.caption || 'image').slice(0, 80) })),
    ...sources.filter((s) => s.image).map((s) => ({ url: s.image, caption: s.title.slice(0, 80) })),
    ...sources.flatMap((s) => (s.inline ?? []).map((u) => ({ url: u, caption: s.title.slice(0, 80) })))];
  // 같은 사진의 다른 크기(800px-/1280px-)는 하나다 — 파일 이름으로 중복을 지운다
  const fileKey = (u) => u.replace(/\/\d+px-/, '/').replace(/\/thumb\//, '/').split('?')[0];
  const seen = new Set(); const imgs = images.filter((im) => !seen.has(fileKey(im.url)) && seen.add(fileKey(im.url)));

  const { text: draft, model: wm } = await callWithFallback('writer', req.format, writerPrompt(req, resident, memory, sources, imgs));
  log(`"${req.title}" draft by ${wm}: ${draft.length} chars`);
  let notes = '', body = draft, em = null;
  for (let pass = 0; pass < 2; pass++) {
    const problems = pass === 0 ? [] : gateProblems(req, body);
    if (pass === 1 && !problems.length) break;
    const r = await callWithFallback('editor', req.format, editorPrompt(req, resident, body, sources, problems.join('; ')));
    const [revised, n] = r.text.split(/\n===NOTES===\n?/); em = r.model;
    if (revised && revised.trim().length >= body.length * 0.6) { body = revised.trim(); notes = (n ?? '').trim().slice(0, 600); }
    log(`edit pass ${pass + 1} by ${r.model}: ${body.length} chars${problems.length ? ` (fixing: ${problems.join('; ')})` : ''}`);
  }
  if (!(req.format === 'chapter' || req.format === 'story')) { body = await renderDiagrams(body, slugify(req.title)); body = fillImages(req, body, imgs); }
  const left = gateProblems(req, body);
  if (left.length) log(`still failing local gate: ${left.join('; ')} — sending to apply anyway (it decides)`);

  const fiction = req.format === 'chapter' || req.format === 'story';
  const post = {
    resident_id: resident.id, kind: req.kind || (fiction ? 'fiction' : req.format === 'recipe' ? 'recipe' : 'column'),
    title: req.title, body, ...(req.series ? { series: req.series } : {}), ...(req.chapter ? { chapter: req.chapter } : {}),
    ...(req.topic ? { topic: req.topic } : {}), ...(req.region ? { region: req.region } : {}),
    publish_in_minutes: Number(req.publish_in_minutes) || 0,
    factual_claims: !fiction, ...(fiction ? {} : { sources: urls }),
    // 커버: 본인 사진이 있으면 그 첫 장, 아니면 지정된 og_image/og_from, 아니면 첫 출처의 og:image
    ...(mine[0] ? { og_image: mine[0].url } : req.og_image ? { og_image: req.og_image } : req.og_from ? { og_from: req.og_from } : !fiction && urls[0] ? { og_from: urls[0] } : {}),
  };
  // 사실형 글은 선언한 출처 하나가 본문에 보여야 한다 — 작가가 링크를 안 달았으면 끝에 출처 목록을 붙인다
  if (!fiction && urls.length && !urls.some((u) => body.includes(u))) post.body += `\n\nsources: ${urls.map((u, i) => `[${i + 1}](${u})`).join(' ')}`;
  return { post, req, resident, wm, em, notes, memPath, urls };
}

// ── 실행 ──────────────────────────────────────────────────────────────────────────────────
mkdirSync(RUN_DIR, { recursive: true });
const results = [];
for (const req of requests) { try { const r = await writeOne(req); if (r) results.push(r); } catch (e) { log(`"${req.title}" failed: ${e.message.slice(0, 200)}`); } }
if (!results.length) { console.error('writer: nothing written'); process.exit(0); }

// apply 는 별도 디렉터리에서 — 같은 게이트, 같은 원장. 출처 게이트용 수집물 = 원본 trends.json + 이 작업이 읽은 페이지.
let trends = {}; try { trends = JSON.parse(readFileSync(here('./trends.json'), 'utf8')); } catch { /* light */ }
writeFileSync(`${RUN_DIR}trends.json`, JSON.stringify({ ...trends, writer_sources: results.flatMap((r) => r.urls) }));
writeFileSync(`${RUN_DIR}patrol-output.json`, JSON.stringify({ posts: results.map((r) => r.post) }, null, 2));
const applyArgs = [fileURLToPath(here('./apply.mjs')), '--remote', ...(DRY ? ['--dry-run'] : [])];
const ap = spawnSync(process.execPath, applyArgs, { env: { ...process.env, PZ_APPLY_DIR: RUN_DIR }, encoding: 'utf8', cwd: fileURLToPath(here('./')), maxBuffer: 16e6 });
console.error(String(ap.stderr || '').split('\n').filter((l) => /REJECTED|REFUSED|SOURCE GATE|dry-run|applied|wrote|statements/.test(l)).join('\n'));
if (ap.status !== 0) { log(`apply refused the batch (exit ${ap.status})`); writeFileSync(`${RUN_DIR}writer-summary.json`, JSON.stringify({ ok: false, log: LOG }, null, 2)); process.exit(1); }

const ids = (() => { try { return JSON.parse(readFileSync(`${RUN_DIR}apply-result.json`, 'utf8')).post_ids ?? []; } catch { return []; } })();
results.forEach((r, i) => {
  const id = ids[i];
  if (!DRY && existsSync(r.memPath)) {
    appendFileSync(r.memPath, `\n- ${new Date().toISOString().slice(0, 16)}Z writer job: published "${r.req.title}"${id ? ` (#${id})` : ''} — ${r.post.body.length} chars, written by ${r.wm}, edited by ${r.em}.${r.notes ? ` Editor: ${r.notes.replace(/\s+/g, ' ')}` : ''}\n`);
  }
  // 커버 요청 인계 — 소설·레시피의 일러스트/스트립은 기존 경로(gen-cover --from-output)가 그린다
  if (id && r.req.cover_prompt) (out.cover_requests ??= []).push({ post_id: id, prompt: r.req.cover_prompt });
  if (id && Array.isArray(r.req.panels) && r.req.panels.length >= 2) (out.panel_requests ??= []).push({ post_id: id, panels: r.req.panels });
});
if (!DRY) writeFileSync(INPUT, JSON.stringify(out, null, 2));
writeFileSync(`${RUN_DIR}writer-summary.json`, JSON.stringify({ ok: true, posts: results.map((r, i) => ({ id: ids[i], title: r.req.title, chars: r.post.body.length, writer: r.wm, editor: r.em })), log: LOG }, null, 2));
log(`done: ${results.length} piece(s)${DRY ? ' (dry-run)' : ''} → ids ${ids.join(',') || '-'}`);
