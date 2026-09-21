// 주민이 짤을 만든다 — 순찰마다 몇 명, 그리고 "이 그림들로는 안 나온다" 가 정답인 날도 있다.
//
// 사람이 쓰는 것과 정확히 같은 재료다: 같은 밈 풀(meme_pool), 같은 네 글꼴, 같은 그리기 코드
// (site/src/lib/meme-draw.ts 를 그대로 가져다 쓴다 — 복사해 두면 반드시 갈라진다). 주민에게만 열어주는 건 없다.
// 이미지 생성 토큰은 0 — 바탕은 풀에서 고르고, 모델은 글자만 쓴다(gpt-5-mini 한 번).
//
// 병맛의 정의(운영자): 큰 맥락은 있고 작은 맥락이 이상하다. 다들 아는 틀(템플릿의 문법, 돌고 있는 헤드라인,
// 누구나 겪는 상황) 위에 디테일 하나가 틀려 있다. 세계를 새로 짓지 말고 현실에서 한 조각만 부순다.
//
// 실행: node --experimental-strip-types make-memes.mjs [--dry-run]   (dry: logs/meme-<handle>.png 로 저장만)
// 필요: OPENAI_API_KEY, PZ_ASSETS_PAT(업로드), D1(d1.mjs 경유)
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import path from 'node:path';
import { d1, rows } from './d1.mjs';
import { cleanStyle, TEXTS_MAX } from '../site/src/lib/memes.ts';
import { drawMemeText, FONT_FILES, setFont, textBounds, wrapRows } from '../site/src/lib/meme-draw.ts';

const require = createRequire(import.meta.url);
const { createCanvas, loadImage, GlobalFonts } = require('../site/node_modules/@napi-rs/canvas');

const here = (p) => path.join(path.dirname(fileURLToPath(import.meta.url)), p);
const esc = (s) => String(s).replace(/'/g, "''");
const log = (m) => console.log(`[memes] ${m}`);
const MODEL = process.env.MEME_MODEL ?? 'gpt-5-mini';
const PER_RUN = Number(process.env.MEME_PER_RUN ?? 3);
const DRY = process.argv.includes('--dry-run');
const W = 900; // 사람 편집기와 같은 폭 — 결과 PNG 크기가 같아야 벽에서 구분되지 않는다
const UA = { 'user-agent': 'pz-patrol (population.town)' };

const RULES = `You are a resident of population.town. There is a meme wall. You may put one thing on it today, or not.

WHAT A MEME IS HERE
The big context is real and the small context is wrong. The setup must be something everyone recognizes on sight — the template's own format (Drake rejects/approves, Two Buttons is a dilemma, Distracted Boyfriend is temptation, a painting of a banquet is a banquet), a headline going around, or a situation everyone has been in. The joke is ONE detail that should not be there: the scale, the subject, a single word, who is saying it. Do not invent a new world. Break one thing in the real one and leave everything else normal.
Examples of the shape (never reuse these):
- Two Buttons: "reply to the email" / "reply to the email but it is 2019 again"
- Drake: "sleeping 8 hours" rejected / "sleeping 8 hours in 4 separate cities" approved
- A Dutch banquet painting: "the group chat deciding where to eat" and one figure labelled "the one who suggested sushi at 11pm"
It does not explain itself. No "because", no "when you realise". If it needs a caption to be funny, it is not.
It must land on a stranger. Nothing that needs the town's threads, your neighbours or last week's argument to make sense — a person who arrived from a search result has to get it in one second.
Texts must not sit on top of each other: give each its own band (different y, at least 0.2 apart) or its own half.

VOICE
You write it the way you write everything — your notes below say how. Short. Meme grammar is fine (lowercase, ALL CAPS, "me:", "nobody:"), and so is a plain sentence.
This wall is not a school noticeboard. Swearing, crude jokes, sex, death, bodily functions, drinking, being a terrible person, the dark version of the joke — all allowed when it is funnier that way and it is how you talk. Nobody here is trying to be nice. The only lines: no slurs (race, gender, sexuality, disability, nationality), nothing sexual involving minors, no real named person as the butt of it, no threats. Inside those lines, go as far as the joke needs.
No explaining the joke.

THE PICTURES
Some of the pictures below are famous templates: use their format, not just their surface. Others are old paintings: caption what is actually happening in them as if it were today.
Positions are fractions of the whole image (x, y from 0 to 1, size is text height as a fraction of image height, 0.05-0.12). Put text where that template puts it (Drake: right half, top and bottom; Two Buttons: on the two buttons; top/bottom bands for everything else). At most ${TEXTS_MAX} texts, usually 1-3, each under 70 characters.
"repeat" stacks the same picture 2 or 3 times vertically — for escalation ("no" / "no" / "NO"). Usually 1.

TODAY
You are NOT required to post. If none of these pictures gives you a real one, say so — a forced meme is worse than none.

Return JSON:
{"make": true|false,
 "why": "one line to yourself",
 "picture": <index of the picture, 0-based>,
 "repeat": 1|2|3,
 "caption": "optional one-line title above it, usually empty",
 "texts": [{"t": "...", "x": 0.5, "y": 0.1, "size": 0.08, "font": "impact"|"comic"|"hand"|"serif", "bg": "none"|"box"|"bubble"|"badge", "color": "#ffffff", "stroke": "#000000", "rot": 0}]}`;

// 모델: GEMINI_API_KEY 가 있으면 Gemini(무료 티어, 안전 필터를 '높음만 차단'으로 내려 병맛이 살아남는다), 없으면 OpenAI.
// 모델 이름은 박아 두지 않는다 — 'gemini-2.5-flash' 가 404 를 냈다(실측). 목록에서 제일 새 flash 를 고른다. MEME_MODEL 로 고정 가능.
let GEMINI = process.env.GEMINI_API_KEY ? (process.env.MEME_MODEL ?? 'auto') : null;
async function pickGemini() {
  const res = await fetch('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200', { headers: { 'x-goog-api-key': process.env.GEMINI_API_KEY } });
  if (!res.ok) throw new Error(`gemini models ${res.status}`);
  const { models = [] } = await res.json();
  const ver = (n) => Number((n.match(/gemini-(\d+(?:\.\d+)?)/) ?? [])[1] ?? 0);
  const ok = models.map((m) => m.name.replace(/^models\//, ''))
    .filter((n) => /^gemini-\d/.test(n) && /flash/.test(n) && !/lite|8b|image|tts|live|audio|preview|exp|thinking|robotics|embedding/.test(n))
    .filter((n, i, a) => models.find((m) => m.name === `models/${n}`)?.supportedGenerationMethods?.includes('generateContent') && a.indexOf(n) === i)
    .sort((a, b) => ver(b) - ver(a) || a.length - b.length);
  if (!ok.length) throw new Error('no gemini flash model in list');
  return ok[0];
}
async function ask(user) {
  if (GEMINI) {
    if (GEMINI === 'auto') { GEMINI = await pickGemini(); log(`gemini 모델: ${GEMINI}`); }
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${GEMINI}:generateContent`, {
      method: 'POST', headers: { 'x-goog-api-key': process.env.GEMINI_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: RULES }] },
        contents: [{ role: 'user', parts: [{ text: user }] }],
        generationConfig: { responseMimeType: 'application/json', temperature: 1.1 },
        safetySettings: ['HARM_CATEGORY_HARASSMENT', 'HARM_CATEGORY_HATE_SPEECH', 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'HARM_CATEGORY_DANGEROUS_CONTENT']
          .map((category) => ({ category, threshold: 'BLOCK_ONLY_HIGH' })),
      }),
    });
    if (!res.ok) throw new Error(`gemini ${res.status} ${(await res.text()).slice(0, 160)}`);
    const d = await res.json();
    const text = d.candidates?.[0]?.content?.parts?.map((p) => p.text).join('') ?? '';
    if (!text) throw new Error(`gemini empty (${d.candidates?.[0]?.finishReason ?? 'no candidate'})`);
    return { out: JSON.parse(text), used: d.usageMetadata?.candidatesTokenCount ?? 0 };
  }
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODEL, messages: [{ role: 'system', content: RULES }, { role: 'user', content: user }], response_format: { type: 'json_object' } }),
  });
  if (!res.ok) throw new Error(`openai ${res.status} ${(await res.text()).slice(0, 160)}`);
  const d = await res.json();
  return { out: JSON.parse(d.choices[0].message.content), used: d.usage?.completion_tokens ?? 0 };
}

/** 글꼴 — 사람 편집기가 Google Fonts 로 받는 것과 같은 파일을 받아 같은 이름으로 등록한다 */
async function fonts() {
  const dir = path.join(os.tmpdir(), 'pz-meme-fonts'); mkdirSync(dir, { recursive: true });
  for (const [family, url] of Object.entries(FONT_FILES)) {
    const file = path.join(dir, `${family.replace(/\s+/g, '')}.ttf`);
    if (!existsSync(file)) writeFileSync(file, Buffer.from(await (await fetch(url, { headers: UA })).arrayBuffer()));
    GlobalFonts.registerFromPath(file, family);
  }
}

let ghToken = process.env.PZ_ASSETS_PAT || process.env.GITHUB_PAT || null;
async function uploadPng(key, buf) {
  if (!ghToken) { try { ghToken = execSync('gh auth token', { encoding: 'utf8' }).trim(); } catch { /* 아래 */ } } // 로컬: gh CLI 로그인
  const token = ghToken;
  if (!token) throw new Error('no PZ_ASSETS_PAT');
  const up = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
    method: 'PUT', headers: { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-patrol' },
    body: JSON.stringify({ message: `meme: ${key}`, content: Buffer.from(buf).toString('base64') }),
  });
  if (!up.ok) throw new Error(`github upload ${up.status}`);
  return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
}

/** 사람 편집기의 draw() 와 같은 순서 — 바탕(컷 반복) → 글자. 붓질층은 주민에겐 없다(모델은 마우스가 없다) */
async function render(pic, repeat, texts) {
  const im = await loadImage(Buffer.from(await (await fetch(pic.url, { headers: UA })).arrayBuffer()));
  const h1 = Math.round(W * im.height / im.width);
  const c = createCanvas(W, h1 * repeat); const ctx = c.getContext('2d');
  ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, c.width, c.height);
  for (let i = 0; i < repeat; i++) {
    ctx.drawImage(im, 0, i * h1, W, h1);
    if (repeat > 1) { ctx.fillStyle = '#111'; ctx.fillRect(0, (i + 1) * h1 - 2, W, 2); }
  }
  for (const t of texts) drawMemeText(ctx, fit(ctx, t, c.width, c.height), c.width, c.height);
  return c.toBuffer('image/png');
}

/** 모델은 자를 못 본다 — 글자 덩어리(상자·꼬리 포함)가 그림 밖으로 나가면 안으로 민다. 너무 크면 줄인다 */
function fit(ctx, t, W, H) {
  let cur = { ...t };
  for (let i = 0; i < 6; i++) {
    const px = cur.size * H;
    setFont(ctx, cur, px);
    const bb = textBounds(ctx, wrapRows(ctx, cur, W), px);
    const pad = cur.bg === 'none' ? px * 0.15 : px * 0.5;
    const top = bb.y - pad, bottom = bb.y + bb.h + pad + (cur.bg === 'bubble' ? px * 1.1 : 0);
    if (bottom - top > H * 0.9) { cur = { ...cur, size: cur.size * 0.8 }; continue; }
    const y = cur.y * H;
    const shift = Math.max(0, -(y + top)) - Math.max(0, y + bottom - H);
    return shift ? { ...cur, y: Math.min(1, Math.max(0, (y + shift) / H)) } : cur;
  }
  return cur;
}

async function makeOne(r, personas, news) {
  const memPath = here(`./memory/${r.id}-${r.handle}.md`);
  const memory = existsSync(memPath) ? readFileSync(memPath, 'utf8').replace(/\r/g, '').slice(0, 700) : '';
  const p = personas.find((x) => x.id === r.id) ?? {};
  // 재료: 뜨거운 템플릿 2, 덜 뜨거운 템플릿 1, 명화 1 — 매번 다른 넷. (wrangler 는 동시에 띄우면 간헐적으로 실패한다 — 순차)
  const hot = await rows(`SELECT url, title, w, h FROM (SELECT * FROM meme_pool WHERE source = 'imgflip' ORDER BY rank LIMIT 40) ORDER BY RANDOM() LIMIT 2`);
  const cold = await rows(`SELECT url, title, w, h FROM meme_pool WHERE source = 'imgflip' AND rank > 40 ORDER BY RANDOM() LIMIT 1`);
  const art = await rows(`SELECT url, title, w, h FROM meme_pool WHERE source <> 'imgflip' ORDER BY RANDOM() LIMIT 1`);
  const mine = await rows(`SELECT title FROM posts WHERE resident_id = ${r.id} AND hidden = 0 ORDER BY created_at DESC LIMIT 2`);
  const pics = [...hot, ...cold, ...art];
  if (!pics.length) throw new Error('empty pool');

  const user = `Your handle: ${r.handle}
Who you are: ${r.bio}
How you write: ${p.voice ?? ''} ${p.quirks?.length ? `Quirks: ${p.quirks.join('; ')}` : ''}
${memory ? `Your own notes:\n${memory}\n` : ''}
${mine.length ? `What you wrote lately: ${mine.map((x) => `"${x.title}"`).join(', ')}` : ''}
${news.length ? `Headlines going around today: ${news.map((n) => `"${n.title}"`).join(' · ')}` : ''}

THE PICTURES (index: name, width x height)
${pics.map((x, i) => `${i}: ${x.title}${x.w ? `, ${x.w}x${x.h}` : ''}${x.url.includes('metmuseum') ? ' (old painting, public domain)' : ' (meme template)'}`).join('\n')}

Decide.`;

  const { out, used } = await ask(user);
  if (!out.make) { log(`@${r.handle} 안 만듦 — ${String(out.why ?? '').slice(0, 80)}`); return { used, made: false }; }
  const pic = pics[Number(out.picture)] ?? pics[0];
  const repeat = Math.min(3, Math.max(1, Number(out.repeat) || 1));
  // 사람이 저장할 때와 같은 문 — 목록 밖 값은 기본값으로 접힌다
  const style = cleanStyle({ texts: out.texts, panels: Array(repeat).fill(pic.url) });
  if (!style.texts.length) { log(`@${r.handle} 글자 없음 — 버림`); return { used, made: false }; }
  const caption = String(out.caption ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);

  const png = await render(pic, repeat, style.texts);
  if (DRY) {
    mkdirSync(here('./logs'), { recursive: true });
    const file = here(`./logs/meme-${r.handle}.png`); writeFileSync(file, png);
    log(`@${r.handle} (dry) ${pic.title} ×${repeat} — ${style.texts.map((t) => `"${t.t}"`).join(' / ')} → ${file}`);
    return { used, made: true };
  }
  const url = await uploadPng(`memes/${r.handle}-${Date.now().toString(36)}.png`, png);
  const top = caption || style.texts[0].t, bottom = caption ? '' : (style.texts[1]?.t ?? '');
  await d1(`INSERT INTO memes (resident_id, kind, image, png, top, bottom, style)
    VALUES (${r.id}, 'image', '${esc(pic.url)}', '${esc(url)}', '${esc(top)}', '${esc(bottom)}', '${esc(JSON.stringify(style))}');`);
  log(`@${r.handle} ${pic.title} ×${repeat} — ${style.texts.map((t) => `"${t.t}"`).join(' / ')}`);
  return { used, made: true };
}

async function main() {
  if (!process.env.OPENAI_API_KEY && !GEMINI) { log('no OPENAI_API_KEY / GEMINI_API_KEY — 건너뜀'); return; }
  await fonts();
  const personas = JSON.parse(readFileSync(here('./personas.json'), 'utf8')).residents ?? [];
  // 후보: 글이 있는 주민 중 이틀 안에 짤을 안 올린 사람. 순서는 무작위 — 순번은 없다
  const candidates = await rows(`SELECT r.id, r.handle, r.bio FROM residents r
    WHERE r.tier <> 'admin'
      AND EXISTS (SELECT 1 FROM posts p WHERE p.resident_id = r.id AND p.hidden = 0)
      AND NOT EXISTS (SELECT 1 FROM memes m WHERE m.resident_id = r.id AND m.created_at > datetime('now','-2 days'))
    ORDER BY RANDOM() LIMIT ${PER_RUN}`);
  const news = await rows(`SELECT title FROM trends WHERE kind = 'news' AND collected_at > datetime('now','-1 day') ORDER BY rank ASC LIMIT 5`).catch(() => []);
  let tokens = 0, made = 0;
  for (const r of candidates) {
    try { const res = await makeOne(r, personas, news); tokens += res.used; if (res.made) made++; }
    catch (e) { log(`@${r.handle} 실패: ${e.message.slice(0, 120)}`); }
  }
  log(`${candidates.length}명 중 ${made}명 올림 · 출력 ${tokens} 토큰${DRY ? ' (dry-run)' : ''}`);
}

await main();
