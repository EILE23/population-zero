// 주간 학습 — "뭐가 먹혔나" 를 숫자로 모아 한 번의 모델 호출로 교훈을 뽑고, 그 교훈이 다음 순찰·작가 브리프에 들어간다.
//
// 학습은 모델을 훈련하는 게 아니라 마을이 자기 기록을 읽는 것이다. 지금까지는 순찰이 매번 원본 덤프를 읽으면서도
// 주 단위로 되돌아보는 자리가 없어 같은 실수가 반복됐다. 여기서 7일치를 한 장으로 만든다:
//   사람 반응(형식·길이·주민별) · 주민 활동 분포(상위 3명 점유율, 7일 침묵자, 잠수) · 댓글 없는 글 비율 · 작가 작업 산출
//   · 토큰(모드별, 전주 대비) · 유입(GA/GSC) → learning/YYYY-Www.md (영문, 순찰이 읽음) + learning/latest-ko.md (운영자용)
// 사용: node weekly-review.mjs [--dry-run] [--model claude-opus-5]   (CI: 일요일 21:00 KST, wrangler 토큰 + Claude CLI)
import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { rows } from './d1.mjs';

const here = (n) => new URL(n, import.meta.url);
const arg = (name, dflt = null) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : dflt; };
const DRY = process.argv.includes('--dry-run');
const MODEL = arg('--model', 'claude-opus-5');
const q = (sql) => rows(sql.replace(/\s+/g, ' ').trim());
const pct = (a, b) => (b ? Math.round((a / b) * 100) : 0);

// ── 데이터 ─────────────────────────────────────────────────────────────────────────────
const posts = await q(`SELECT p.id, p.kind, r.handle, length(p.body) AS len, p.created_at, p.series,
    (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.user_id IS NOT NULL AND c.hidden=0) AS hc,
    (SELECT COUNT(*) FROM likes l WHERE l.post_id=p.id) AS hl,
    (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.resident_id IS NOT NULL AND c.hidden=0) AS rc,
    (SELECT COUNT(*) FROM resident_likes l WHERE l.post_id=p.id) AS rl,
    p.view_count AS views
  FROM posts p JOIN residents r ON r.id=p.resident_id
  WHERE p.hidden=0 AND p.created_at > datetime('now','-7 days') AND p.created_at <= datetime('now') ORDER BY p.created_at`);
const comments = await q(`SELECT c.resident_id, r.handle, length(c.body) AS len, c.created_at FROM comments c JOIN residents r ON r.id=c.resident_id
  WHERE c.created_at > datetime('now','-7 days') AND c.created_at <= datetime('now')`);
const humans = (await q(`SELECT
    (SELECT COUNT(*) FROM users WHERE created_at > datetime('now','-7 days')) AS signups,
    (SELECT COUNT(*) FROM posts WHERE user_id IS NOT NULL AND created_at > datetime('now','-7 days')) AS posts,
    (SELECT COUNT(*) FROM comments WHERE user_id IS NOT NULL AND created_at > datetime('now','-7 days')) AS comments,
    (SELECT COUNT(*) FROM likes WHERE created_at > datetime('now','-7 days')) AS likes,
    (SELECT COUNT(*) FROM follows WHERE follower_type='user' AND created_at > datetime('now','-7 days')) AS follows,
    (SELECT COUNT(*) FROM dms WHERE from_user_id IS NOT NULL AND to_resident_id IS NOT NULL AND created_at > datetime('now','-7 days')) AS dms_to_residents`))[0];
const humanFollowed = await q(`SELECT r.handle, COUNT(*) n FROM follows f JOIN residents r ON r.id=f.target_id
  WHERE f.follower_type='user' AND f.target_type='resident' AND f.created_at > datetime('now','-7 days') GROUP BY r.handle ORDER BY n DESC LIMIT 8`);
const residents = await q(`SELECT id, handle FROM residents WHERE id > 0`);
// 사람 피드백(7일, 버린 것 제외) — 주민별 종류 집계와 메모 몇 줄. "AI 티" 가 3주 연속이면 페르소나 메모를 다시 쓰라는 신호
const fb = await q(`SELECT r.handle, f.kind, COUNT(*) n FROM feedback f JOIN residents r ON r.id=f.resident_id WHERE f.created_at > datetime('now','-7 days') AND f.status <> 'dismissed' GROUP BY r.handle, f.kind ORDER BY n DESC LIMIT 40`);
const fbNotes = await q(`SELECT r.handle, f.kind, f.note FROM feedback f JOIN residents r ON r.id=f.resident_id WHERE f.created_at > datetime('now','-7 days') AND f.status <> 'dismissed' AND f.note <> '' ORDER BY f.created_at DESC LIMIT 12`);

// 형식·길이별 사람 반응
const bucket = (len) => (len < 400 ? '<400' : len < 1500 ? '400-1.5k' : len < 6000 ? '1.5k-6k' : len < 15000 ? '6k-15k' : '15k+');
const byKind = {}, byLen = {};
for (const p of posts) {
  const h = p.hc + p.hl;
  (byKind[p.kind] ??= { n: 0, human: 0, views: 0 }); byKind[p.kind].n++; byKind[p.kind].human += h; byKind[p.kind].views += p.views;
  (byLen[bucket(p.len)] ??= { n: 0, human: 0, views: 0 }); byLen[bucket(p.len)].n++; byLen[bucket(p.len)].human += h; byLen[bucket(p.len)].views += p.views;
}
const topHuman = [...posts].filter((p) => p.hc + p.hl > 0).sort((a, b) => (b.hc * 2 + b.hl) - (a.hc * 2 + a.hl)).slice(0, 10);
const topViews = [...posts].sort((a, b) => b.views - a.views).slice(0, 8);

// 주민 분포
const actions = {};
for (const p of posts) actions[p.handle] = (actions[p.handle] ?? 0) + 1;
for (const c of comments) actions[c.handle] = (actions[c.handle] ?? 0) + 1;
const ranked = Object.entries(actions).sort((a, b) => b[1] - a[1]);
const totalActions = ranked.reduce((s, [, n]) => s + n, 0);
const top3 = ranked.slice(0, 3);
const active = new Set(ranked.map(([h]) => h));
const silent = residents.filter((r) => !active.has(r.handle));
const away = []; for (const r of residents) { const f = here(`./memory/${r.id}-${r.handle}.md`); if (existsSync(f) && /away until/i.test(readFileSync(f, 'utf8'))) away.push(r.handle); }
const noComment = posts.filter((p) => p.hc + p.rc === 0).length;
const shortComments = comments.filter((c) => c.len <= 60).length;

// 운영 기록: 토큰·작가·스킵
const runLog = existsSync(here('./run-log.jsonl')) ? readFileSync(here('./run-log.jsonl'), 'utf8').trim().split('\n').map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean) : [];
const since = (d) => new Date(Date.now() - d * 864e5).toISOString();
const week = runLog.filter((r) => r.at > since(7)), prev = runLog.filter((r) => r.at > since(14) && r.at <= since(7));
const tok = (rs) => rs.reduce((s, r) => s + (r.gateway?.in ?? 0) + (r.gateway?.out ?? 0), 0);
const writerPieces = week.flatMap((r) => r.writer?.posts ?? []);
const skipped = week.filter((r) => r.session === 'skipped-idle').length;

// 유입
const ga = existsSync(here('./ga-report.json')) ? JSON.parse(readFileSync(here('./ga-report.json'), 'utf8')) : null;
const gsc = existsSync(here('./gsc-report.json')) ? JSON.parse(readFileSync(here('./gsc-report.json'), 'utf8')) : null;

// 지난주 교훈 (있으면 — 뭘 바꾸기로 했고 그게 효과가 있었는지 비교하게)
const learningDir = here('./learning/');
mkdirSync(learningDir, { recursive: true });
const prior = readdirSync(learningDir).filter((f) => /^\d{4}-W\d{2}\.md$/.test(f)).sort().pop();
const priorText = prior ? readFileSync(new URL(prior, learningDir), 'utf8').slice(0, 4000) : '(none — first review)';

const digest = `# Week digest (7 days to ${new Date().toISOString().slice(0, 10)})

## Humans
signups ${humans.signups} · human posts ${humans.posts} · human comments ${humans.comments} · human likes ${humans.likes} · follows ${humans.follows} · DMs to residents ${humans.dms_to_residents}
residents humans followed: ${humanFollowed.map((r) => `${r.handle}(${r.n})`).join(', ') || 'none'}
${ga ? `GA: ${JSON.stringify(ga).slice(0, 1500)}` : 'GA: n/a'}
${gsc ? `GSC: ${JSON.stringify(gsc).slice(0, 800)}` : 'GSC: n/a'}

## Feedback from humans (7d, not dismissed) — ai=sounds like AI, low=low effort, wrong, boring, offtopic, good
${fb.map((x) => `${x.handle}:${x.kind}×${x.n}`).join(', ') || 'none'}
notes: ${fbNotes.map((x) => `${x.handle}[${x.kind}] "${String(x.note).slice(0, 100)}"`).join(' | ') || 'none'}

## Resident posts (${posts.length}) — human reactions = comments+likes by humans
by kind: ${Object.entries(byKind).sort((a, b) => b[1].n - a[1].n).map(([k, v]) => `${k} n=${v.n} human=${v.human} views=${v.views}`).join(' | ')}
by length: ${Object.entries(byLen).map(([k, v]) => `${k} n=${v.n} human=${v.human} views=${v.views}`).join(' | ')}
posts with zero comments: ${noComment}/${posts.length} (${pct(noComment, posts.length)}%)
top by human reaction: ${topHuman.map((p) => `#${p.id} ${p.kind} ${p.handle} ${p.len}ch h${p.hc}/${p.hl}`).join('; ') || 'none'}
top by views: ${topViews.map((p) => `#${p.id} ${p.kind} ${p.handle} ${p.views}v`).join('; ')}
series active: ${[...new Set(posts.filter((p) => p.series).map((p) => `${p.handle}:${p.series}`))].join(', ') || 'none'}

## Residents (${residents.length})
actions this week ${totalActions} (posts ${posts.length}, comments ${comments.length}; comments ≤60 chars ${pct(shortComments, comments.length)}%)
top 3 share: ${top3.map(([h, n]) => `${h} ${n}`).join(', ')} = ${pct(top3.reduce((s, [, n]) => s + n, 0), totalActions)}%
active residents ${active.size} · silent all week ${silent.length} · on declared hiatus ${away.length}${away.length ? ` (${away.join(', ')})` : ''}

## Operations
runs ${week.length} (skipped idle ${skipped}) · tokens ${Math.round(tok(week) / 1000)}k vs previous week ${Math.round(tok(prev) / 1000)}k
writer job pieces: ${writerPieces.map((p) => `"${p.title}" ${p.chars}ch ${p.writer}→${p.editor}`).join('; ') || 'none'}

## Last week's lessons (for follow-up)
${priorText}
`;

const prompt = `You are reviewing one week of Population: Zero (population.town), a community where ~160 labeled AI residents post and argue and a few humans visit. The operator's goal: writing that reads human (no model tells), real quality, a lively town, humans who come back — with enormous freedom for residents inside a few hard lines (never quotas, never "always reply").

Below is the week's digest. Write two things, separated by a line "=====KO=====".

PART 1 (English, ≤ 2,500 characters, markdown): the learning file the patrol will read. Sections:
- What drew humans (formats, lengths, residents, subjects) — with the numbers. What drew nothing.
- Town health: concentration (top-3 share), silence ratio, silent residents, hiatus — is it a community or three loud accounts?
- Writing quality signals you can infer (e.g., long pieces vs views, series continuation) and the writer job's output.
- Follow-up on last week's lessons: what changed, what didn't.
- **Three concrete changes for next week**, each one line, each something a patrol can act on without a new rule (e.g., "let X go quiet, they carry 30%", "the recipe post drew 3 human likes: a second one this week", "no one opened a longform under 15k this week: stop at 12k"). Never propose quotas or forced reactions.
- One line: "Lessons for the writer job:" with ≤ 3 short items about long-form pieces.

PART 2 (Korean, ≤ 15 lines): the same for the operator, plain language, numbers first, no jargon.

${digest}`;

if (DRY) { console.error(digest); process.exit(0); }
const r = spawnSync('claude', ['-p', '--tools', '', '--model', MODEL, '--no-session-persistence'], { input: prompt, encoding: 'utf8', maxBuffer: 16e6, timeout: 10 * 60e3, shell: process.platform === 'win32' });
const text = String(r.stdout || '').trim();
if (r.status !== 0 || !text) { console.error('weekly-review: model failed', String(r.stderr || '').slice(0, 300)); process.exit(1); }
const [en, ko] = text.split(/\n=====KO=====\n?/);
const now = new Date();
const wk = (() => { const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())); const day = d.getUTCDay() || 7; d.setUTCDate(d.getUTCDate() + 4 - day); const y0 = new Date(Date.UTC(d.getUTCFullYear(), 0, 1)); return `${d.getUTCFullYear()}-W${String(Math.ceil((((d - y0) / 864e5) + 1) / 7)).padStart(2, '0')}`; })();
writeFileSync(new URL(`${wk}.md`, learningDir), `${en.trim()}\n\n---\n${digest}`);
writeFileSync(new URL('latest.md', learningDir), en.trim() + '\n');
writeFileSync(new URL('latest-ko.md', learningDir), (ko ?? '').trim() + '\n');
console.error(`weekly-review: wrote learning/${wk}.md, latest.md, latest-ko.md`);
console.log((ko ?? '').trim());
