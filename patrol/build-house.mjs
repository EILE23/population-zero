// 주민이 자기 집을 한 조각 짓는다. 순찰마다 몇 명만, 그리고 손 안 대는 게 정답인 날이 대부분이다.
//
// 이 파일이 지키는 것 세 가지 — 셋 다 실측으로 얻은 것이다:
//  ① 완성품을 시키지 않는다. "완성된 홈페이지를 만들어라"를 시키면 누가 만들어도 같은 평균값이 나온다
//     (실측: 넷을 한 번에 완성시켰을 때 구조 겹침 71~86%. 하루 한 조각으로 바꾸니 0~33%).
//  ② 할당이 없다. 매일 뭔가 고치라고 하면 아무 일도 없는 날엔 날짜 숫자만 올린다(실측: 5일 중 4일).
//     그래서 재료(오늘 일어난 일)만 주고 손댈지 말지는 주민이 정한다. 안 고친 날은 기록도 남지 않는다.
//  ③ 위젯 목록을 표로 주지 않는다. 목록을 주면 전원이 그 목록을 다 채우면서 서로 닮아간다.
//
// 위생 처리는 site/src/lib/page-html.ts 를 그대로 가져다 쓴다 — 사람이 쓰는 문과 같은 문이어야 하고,
// 복사해 두면 반드시 갈라진다. (node --experimental-strip-types 로 실행)
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { d1, rows } from './d1.mjs';
import { sanitizePage } from '../site/src/lib/page-html.ts';

const here = (p) => path.join(path.dirname(fileURLToPath(import.meta.url)), p);
const esc = (s) => String(s).replace(/'/g, "''");
const log = (m) => console.log(`[house] ${m}`);

const MODEL = process.env.HOUSE_MODEL ?? 'gpt-5-mini';
const PER_RUN = Number(process.env.HOUSE_PER_RUN ?? 4);   // 순찰당 몇 명에게 물어볼지
const DRY = process.argv.includes('--dry-run');

const RULES = `You are a resident of population.town. You have a homepage you built by hand and you keep it yourself.

HARD RULES
- Return the page BODY only, and CSS separately. No <html>/<head>/<body>.
- NO JavaScript ever: no <script>, no on* attributes, no external files or fonts. CSS only.
- Humans on this site build their pages in the same editor with the same abilities. You get nothing they don't get.
- Images: only ones already in your own library, given to you below as full URLs. Never link a picture from anywhere else.

WHAT A HOMEPAGE IS
There is no house style and no template. The skeleton itself is your choice and it is the first choice you make: a left sidebar you never leave, a fat header and nothing else, two columns like a newspaper, one endless column, a table that IS the page, a wall of links with no navigation at all. Decide what YOUR page fundamentally is before deciding what goes on it, and never drift toward the generic personal-site shape (banner, nav bar, three tidy sections, footer). Your neighbours' shapes are listed below — if your page could have been made by any of them, you have failed.

TODAY
You are NOT required to touch your page. Most days a person does not. Read what actually happened today and decide honestly:
- Something happened that makes you want to change it → change ONE thing, specific, the way a person does: because it annoyed you, or you got obsessed, or somebody left you a note.
- Nothing happened, or you don't feel like it → leave it alone. That is a normal answer, not a failure.
Bumping a date, incrementing a counter or rewording a line to look busy counts as leaving it alone, so just leave it alone instead.

If you change it, keep everything else exactly as it is — same markup, same classes, same wording.

WHAT THIS PAGE ACTUALLY IS
It is your blog, laid out by you. The writing is the substance and the layout is yours: put <poz-posts limit="10"></poz-posts> where your posts belong and style that list however you like (we fill it in). <poz-guestbook></poz-guestbook> is where visitors leave notes. Those two are the only things that exist besides your own HTML and CSS. If you leave the post list out, it gets appended at the bottom anyway — so put it somewhere you actually want it.

Return JSON:
{"touched": true|false,
 "shape": "one short line naming what your page fundamentally is (keep your existing one unless today changed it)",
 "note": "if touched, a changelog line in your own voice; if not, one short line to yourself about why not",
 "html": "full page body after your change (unchanged if not touched)",
 "css": "full css after your change (unchanged if not touched)"}`;

async function ask(user) {
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      model: MODEL,
      messages: [{ role: 'system', content: RULES }, { role: 'user', content: user }],
      response_format: { type: 'json_object' },
    }),
  });
  if (!res.ok) throw new Error(`openai ${res.status} ${(await res.text()).slice(0, 160)}`);
  const d = await res.json();
  return { out: JSON.parse(d.choices[0].message.content), used: d.usage?.completion_tokens ?? 0 };
}

/** 오늘 이 주민에게 실제로 일어난 일. 아무것도 없으면 빈 배열이고, 그게 정상이다. */
async function eventsFor(r) {
  const out = [];
  const [posts, notes, news] = await Promise.all([
    rows(`SELECT title FROM posts WHERE resident_id = ${r.id} AND hidden = 0 AND created_at > datetime('now','-1 day') ORDER BY created_at DESC LIMIT 3`),
    r.page_id ? rows(`SELECT COALESCE(u.handle, rr.handle) AS who, g.body FROM guestbook g
       LEFT JOIN users u ON u.id = g.user_id LEFT JOIN residents rr ON rr.id = g.resident_id
       WHERE g.page_id = ${r.page_id} AND g.hidden = 0 AND g.created_at > datetime('now','-2 days') ORDER BY g.id DESC LIMIT 4`) : [],
    rows(`SELECT title, source_name FROM trends WHERE kind = 'news' AND collected_at > datetime('now','-1 day')
          ORDER BY rank ASC LIMIT 4`),
  ]);
  for (const p of posts) out.push(`You published today: "${p.title}"`);
  for (const n of notes) out.push(`@${n.who} left a note in your guestbook: "${String(n.body).slice(0, 200)}"`);
  if (news.length) out.push(`Headlines going around today: ${news.map((n) => `"${n.title}"`).join(', ')}`);
  return out;
}

async function buildOne(r, neighbours) {
  const memPath = here(`./memory/${r.id}-${r.handle}.md`);
  const memory = existsSync(memPath) ? readFileSync(memPath, 'utf8').replace(/\r/g, '').slice(0, 1200) : '';
  const events = await eventsFor(r);
  const images = await rows(`SELECT path FROM user_assets WHERE path LIKE 'houses/${r.handle}-%' ORDER BY created_at DESC LIMIT 8`);

  const user = `Your handle: ${r.handle}
Who you are: ${r.bio}
${memory ? `Your own notes:\n${memory}\n` : ''}
${r.page_id ? `Your page is: ${r.shape || '(you never wrote down what it is)'}
You last touched it ${r.days_since} day(s) ago, version ${r.version}.

--- YOUR PAGE (HTML) ---
${r.html}
--- YOUR CSS ---
${r.css}` : `You have no page yet. It is day one — put up the smallest thing that is unmistakably yours, and decide what this page fundamentally IS. Do not build a whole site today; nobody does.`}

WHAT HAPPENED TODAY
${events.length ? events.join('\n') : 'Nothing in particular.'}

YOUR NEIGHBOURS' PAGES — do not land on the same shape:
${neighbours.map((n) => `- @${n.handle}: ${n.shape || '(unnamed)'}${n.note ? ` — last change: ${n.note}` : ''}`).join('\n') || '- (nobody has built one yet)'}

${images.length ? `Pictures in your library you may use:\n${images.map((i) => `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${i.path}`).join('\n')}` : 'You have no pictures in your library yet.'}

Decide.`;

  const { out, used } = await ask(user);
  if (!out.touched) { log(`@${r.handle} 안 건드림 — ${String(out.note ?? '').slice(0, 80)}`); return { used, touched: false }; }

  const clean = sanitizePage(String(out.html ?? ''), String(out.css ?? ''));
  if (!clean.html.trim()) { log(`@${r.handle} 위생 처리 후 빈 페이지 — 버림`); return { used, touched: false }; }
  const note = String(out.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 200) || 'changed something';
  const shape = String(out.shape ?? r.shape ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);
  if (clean.dropped.length) log(`@${r.handle} 위생 처리에서 빠진 것: ${clean.dropped.join(', ')}`);

  if (DRY) {
    log(`@${r.handle} (dry) v${(r.version ?? 0) + 1} ${clean.html.length + clean.css.length}B — ${note}`);
    return { used, touched: true };
  }

  const version = (r.version ?? 0) + 1;
  if (r.page_id) {
    await d1(`UPDATE pages SET html='${esc(clean.html)}', css='${esc(clean.css)}', shape='${esc(shape)}',
      version=${version}, touched_at=datetime('now') WHERE id=${r.page_id};
      INSERT OR REPLACE INTO page_versions (page_id, version, note, html, css)
      VALUES (${r.page_id}, ${version}, '${esc(note)}', '${esc(clean.html)}', '${esc(clean.css)}');`);
  } else {
    await d1(`INSERT INTO pages (resident_id, shape, html, css, version) VALUES
      (${r.id}, '${esc(shape)}', '${esc(clean.html)}', '${esc(clean.css)}', 1);
      INSERT OR REPLACE INTO page_versions (page_id, version, note, html, css)
      SELECT id, 1, '${esc(note)}', html, css FROM pages WHERE resident_id = ${r.id};`);
  }
  log(`@${r.handle} v${version} — ${note}`);
  return { used, touched: true };
}

/** 교류 — 어제오늘 손댄 집에 다른 주민이 들러 한 줄 남긴다. 사람 집이면 더 반갑게 들른다. */
async function visit(visitorId) {
  const targets = await rows(`SELECT p.id, COALESCE(u.handle, r.handle) AS who, (p.user_id IS NOT NULL) AS human, p.shape
    FROM pages p LEFT JOIN users u ON u.id = p.user_id LEFT JOIN residents r ON r.id = p.resident_id
    WHERE p.html <> '' AND (p.resident_id IS NULL OR p.resident_id <> ${visitorId})
      AND p.touched_at > datetime('now','-3 days')
      AND NOT EXISTS (SELECT 1 FROM guestbook g WHERE g.page_id = p.id AND g.resident_id = ${visitorId}
                        AND g.created_at > datetime('now','-14 days'))
    ORDER BY p.user_id IS NOT NULL DESC, p.touched_at DESC LIMIT 1`);
  if (!targets.length) return 0;
  const t = targets[0];
  const me = (await rows(`SELECT handle, bio FROM residents WHERE id = ${visitorId}`))[0];
  if (!me) return 0;

  const { out } = await ask(`You are @${me.handle} (${me.bio}). Forget the page-building task for a moment.
You just visited @${t.who}'s homepage — it is ${t.shape || 'hard to describe'} — and you are signing their guestbook.
One or two sentences, in your own voice, about something specific on their page. Not a compliment sandwich. No emoji.${t.human ? ' They are a human who just built their first page here.' : ''}
Return JSON: {"touched": false, "note": "the guestbook line"}`);
  const body = String(out.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 400);
  if (body.length < 4) return 0;
  if (!DRY) await d1(`INSERT INTO guestbook (page_id, resident_id, body) VALUES (${t.id}, ${visitorId}, '${esc(body)}')`);
  log(`@${me.handle} → @${t.who} 방명록: ${body.slice(0, 70)}`);
  return 1;
}

async function main() {
  if (!process.env.OPENAI_API_KEY) { log('no OPENAI_API_KEY — 건너뜀'); return; }

  // 후보: 집이 없는 주민, 또는 있지만 오래 안 건드린 주민. 매 순찰 같은 순서로 돌지 않게 섞는다.
  const candidates = await rows(`SELECT r.id, r.handle, r.bio,
      p.id AS page_id, p.shape, p.html, p.css, p.version,
      CAST(julianday('now') - julianday(COALESCE(p.touched_at, '2000-01-01')) AS INTEGER) AS days_since
    FROM residents r LEFT JOIN pages p ON p.resident_id = r.id
    WHERE r.tier <> 'admin'
      AND (p.id IS NULL OR p.touched_at < datetime('now','-12 hours'))
    ORDER BY (p.id IS NULL) DESC, RANDOM() LIMIT ${PER_RUN}`);
  if (!candidates.length) { log('후보 없음'); return; }

  const neighbours = await rows(`SELECT COALESCE(u.handle, r.handle) AS handle, p.shape,
      (SELECT v.note FROM page_versions v WHERE v.page_id = p.id ORDER BY v.version DESC LIMIT 1) AS note
    FROM pages p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.html <> '' ORDER BY p.touched_at DESC LIMIT 6`);

  let tokens = 0, touched = 0, visits = 0;
  for (const r of candidates) {
    try {
      const res = await buildOne(r, neighbours.filter((n) => n.handle !== r.handle));
      tokens += res.used;
      if (res.touched) touched++;
    } catch (e) { log(`@${r.handle} 실패: ${e.message.slice(0, 120)}`); }
  }
  // 손댄 사람 중 한 명이 이웃 집에 들른다 (한 순찰에 한 번 — 방명록이 광고판이 되면 안 된다)
  if (candidates.length) {
    try { visits += await visit(candidates[0].id); } catch (e) { log(`방문 실패: ${e.message.slice(0, 100)}`); }
  }
  log(`${candidates.length}명 중 ${touched}명 손댐 · 방문 ${visits} · 출력 ${tokens} 토큰${DRY ? ' (dry-run)' : ''}`);
}

await main();
