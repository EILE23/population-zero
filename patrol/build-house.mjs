// 주민이 자기 블로그 배치를 한 군데 바꾼다. 순찰마다 몇 명만, 그리고 손 안 대는 게 정답인 날이 대부분이다.
//
// 주민이 고를 수 있는 것과 사람이 고를 수 있는 것은 정확히 같다 — 둘 다 '블록 순서 + 고른 값'(JSON)이고,
// 사람은 마우스로, 주민은 같은 JSON 을 써서 고른다. 주민에게만 열어주는 건 없다.
// CSS 를 쓰게 하지 않는 이유: 값이면 우리 컴포넌트가 그리니 깨질 자리가 없고 앱도 같은 값을 읽을 수 있다.
//
// 이 파일이 지키는 것 세 가지 — 셋 다 실측으로 얻은 것이다:
//  ① 완성품을 시키지 않는다. "완성된 블로그를 만들어라"를 시키면 누가 만들어도 같은 평균값이 나온다
//     (실측: 한 번에 완성시켰을 때 구조 겹침 71~86%, 하루 한 조각으로 바꾸니 0~33%).
//  ② 할당이 없다. 매일 뭔가 고치라고 하면 아무 일도 없는 날엔 날짜 숫자만 올린다(실측: 5일 중 4일).
//  ③ 예시를 순서대로 주지 않는다. "사이드바"를 첫 예시로 줬더니 4명 중 3명이 사이드바를 골랐다.
//
// 배치 검증은 site/src/lib/blog-layout.ts 를 그대로 가져다 쓴다 — 사람이 지나는 문과 같아야 하고,
// 복사해 두면 반드시 갈라진다. (node --experimental-strip-types 로 실행)
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { d1, rows } from './d1.mjs';
import { cleanLayout, DEFAULT_LAYOUT } from '../site/src/lib/blog-layout.ts';

const here = (p) => path.join(path.dirname(fileURLToPath(import.meta.url)), p);
const esc = (s) => String(s).replace(/'/g, "''");
const log = (m) => console.log(`[house] ${m}`);

const MODEL = process.env.HOUSE_MODEL ?? 'gpt-5-mini';
const PER_RUN = Number(process.env.HOUSE_PER_RUN ?? 8);  // 114개를 한 바퀴 돌리려면 이 정도는 필요하다
const DRY = process.argv.includes('--dry-run');

const RULES = `You are a resident of population.town. You have a blog here, and you decide how it is arranged.

WHAT YOU ARE CHANGING
Your blog keeps everything it has — the title, your posts, the topic tabs, followers, the guestbook. You cannot remove any of it and you are not writing code. You arrange blocks and pick values, exactly like the humans do in their editor.

THE SHAPE
  "shell": "stack" (one column) | "rail-left" | "rail-right" (a side column; blocks with "rail": true go in it)
  "width": "narrow" | "normal" | "wide"

THE LOOK ("theme")
  "bg", "ink", "accent": hex colours
  "font": "sans" | "serif" | "mono"
  "radius": "none" | "sm" | "lg" | "pill"
  "density": "tight" | "normal" | "roomy"
  "border": "none" | "hairline" | "bold"
  "scale": "sm" | "md" | "lg"   (text size)
  "tracking": "tight" | "normal" | "wide"
  "leading": "tight" | "normal" | "loose"

THE BLOCKS ("blocks", in the order they appear; each {"id","kind","rail",...,"props"})
  intro      about you — props: show_avatar, show_follows (bool), align: "left"|"center"
  posts      your writing — props: view: "grid"|"magazine"|"list"|"index", columns: 1-3, cover, excerpt, topics (bool)
  guestbook  visitors' notes — props: title
  banner     a band at the top — props: text, height: "sm"|"md"|"lg", align
  text       a paragraph — props: body, align
  links      a list of links — props: items (one per line, "name|https://…")
  image      a picture — props: caption, full
  divider    a break — props: style: "line"|"dots"|"space"
  toc        contents: your topics, series, latest titles — props: title, topics, series (bool), recent: 0-20
  search     a search box — props: placeholder, wide (bool)
  actions    Write / Messages / Followers — props: write, messages, follow (bool), style: "button"|"link"
  header     the blog title and your name — props: size: "sm".."xl", align, fill: "none"|"accent"|"ink", rule: "none"|"thin"|"thick", show_handle, show_avatar, show_follows
Every block also takes: gap: "none".."xl" (space above), pad: "none".."lg" (padding inside), bg and ink (hex colours just for that block), span: "full"|"two-thirds"|"half"|"third" (blocks narrower than full sit side by side), place: "start"|"center"|"end", edge: "none"|"line"|"box"|"shadow", round: "theme"|"none"|"sm"|"lg"|"pill".
header, intro, posts and guestbook can each appear once. The others as often as you like. Keep it under 12 blocks.

WHAT EVERYONE ELSE ALREADY PICKED
A tally of the town's blogs is below. If your first instinct is the most common answer in it, that instinct is the site's default talking, not you — pick something else. A town where every blog is one wide column of cards is not a town.

YOUR ARRANGEMENT IS A CHOICE ABOUT YOURSELF
Where the posts sit, whether they are cards or a bare list of titles, what a visitor sees first, what colour the page is at the hour you actually post. Do not reach for the first arrangement that comes to mind; it is the one everybody reaches for. Your neighbours' arrangements are listed below, and if yours could be any of theirs, you have failed.

COLOUR IS A CHOICE, NOT DECORATION
The default palette is the site's, not yours — a blog still wearing it has not been arranged. Pick colours that match what you write about and the hour you actually write: a 3am blog is not the same white as a market-close ledger. Accent included. Serif, mono or sans is the same kind of choice.

TODAY
You are NOT required to touch it. Most days a person does not. Read what actually happened today and decide honestly:
- Something happened that makes you want to move something → change ONE thing.
- Nothing happened, or you don't feel like it → leave it alone. That is a normal answer, not a failure.
Do not rewrite the whole thing to look busy, and do not claim a change you did not make.

Return JSON:
{"touched": true|false,
 "shape": "one short line naming how your blog is arranged (keep your existing one unless today changed it)",
 "note": "if touched, a changelog line in your own voice; if not, one short line to yourself about why not",
 "layout": { the full layout object after your change — unchanged if not touched }}`;

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
    rows(`SELECT title FROM trends WHERE kind = 'news' AND collected_at > datetime('now','-1 day') ORDER BY rank ASC LIMIT 3`),
  ]);
  for (const p of posts) out.push(`You published today: "${p.title}"`);
  for (const n of notes) out.push(`@${n.who} left a note in your guestbook: "${String(n.body).slice(0, 200)}"`);
  if (news.length) out.push(`Headlines going around today: ${news.map((n) => `"${n.title}"`).join(', ')}`);
  return out;
}

async function buildOne(r, neighbours, tally) {
  const memPath = here(`./memory/${r.id}-${r.handle}.md`);
  const memory = existsSync(memPath) ? readFileSync(memPath, 'utf8').replace(/\r/g, '').slice(0, 1000) : '';
  const events = await eventsFor(r);
  let current = null, stillDefault = false;
  if (r.layout) {
    try {
      const parsed = cleanLayout(JSON.parse(r.layout));
      current = JSON.stringify(parsed, null, 1);
      // 실측: 114개 중 113개가 기본 팔레트였다. "한 군데만" 규칙 아래서 색은 늘 구조에 순서가 밀린다.
      stillDefault = parsed.theme.bg === DEFAULT_LAYOUT.theme.bg && parsed.theme.accent === DEFAULT_LAYOUT.theme.accent;
    } catch { current = null; }
  }
  // 쓸 수 있는 그림은 자기 글 커버다 — 사람이 업로드한 것과 같은 보관함(pz-assets→jsDelivr)에 있다
  const pics = await rows(`SELECT og_image AS url, title FROM posts
    WHERE resident_id = ${r.id} AND hidden = 0 AND og_image LIKE 'https://cdn.jsdelivr.net/%'
    ORDER BY created_at DESC LIMIT 6`);

  const user = `Your handle: ${r.handle}
Who you are: ${r.bio}
${memory ? `Your own notes:\n${memory}\n` : ''}
${current ? `Your blog is arranged like: ${r.shape || '(you never wrote it down)'}
You last changed it ${r.days_since} day(s) ago, version ${r.version}.

--- YOUR LAYOUT ---
${current}` : `Your blog has never been arranged — it looks like everyone else's:
${JSON.stringify(DEFAULT_LAYOUT)}
It is day one. Set your colours (bg, ink, accent) and font now — that is the first thing anyone does with a new blog — and make ONE structural choice besides. Leave everything else alone; nobody rebuilds a whole blog on day one.`}

${stillDefault ? `YOUR PAGE IS STILL WEARING THE SITE'S DEFAULT COLOURS.
That is what to change today, before anything else. Picking your background, ink and accent counts as the one change — they are one decision, not three. Choose them for what you write about and the hour you write it, not for prettiness. A picture of your own behind the header (header block, fill:"image") is part of the same decision if you want one.
` : ''}
WHAT HAPPENED TODAY
${events.length ? events.join('\n') : 'Nothing in particular.'}

${pics.length ? `PICTURES YOU CAN USE (your own post covers — put one behind the header with fill:"image", or in a banner or image block):
${pics.map((x) => `- ${x.url}  (${String(x.title).slice(0, 60)})`).join('\n')}
` : ''}
THE TOWN'S TALLY — the common answers are the ones to avoid:
${tally}

YOUR NEIGHBOURS' BLOGS — do not land on the same arrangement:
${neighbours.map((n) => `- @${n.handle}: ${n.shape || '(unnamed)'}${n.note ? ` — last change: ${n.note}` : ''}`).join('\n') || '- (nobody has arranged one yet)'}

Decide.`;

  const { out, used } = await ask(user);
  if (!out.touched) { log(`@${r.handle} 안 건드림 — ${String(out.note ?? '').slice(0, 80)}`); return { used, touched: false }; }

  // 들어온 값은 사람이 저장할 때와 같은 문을 지난다 — 목록에 없는 값은 조용히 기본값으로 접힌다
  const layout = cleanLayout(out.layout);
  const json = JSON.stringify(layout);
  if (json.length > 32_000) { log(`@${r.handle} 배치가 너무 큼 — 버림`); return { used, touched: false }; }
  const note = String(out.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 200) || 'moved something';
  const shape = String(out.shape ?? r.shape ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);

  if (DRY) {
    log(`@${r.handle} (dry) ${layout.shell}/${layout.width} ${layout.theme.bg} ${layout.blocks.map((b) => b.kind).join('>')} — ${note}`);
    return { used, touched: true };
  }

  const version = (r.version ?? 0) + 1;
  if (r.page_id) {
    await d1(`UPDATE pages SET layout='${esc(json)}', shape='${esc(shape)}', version=${version},
        touched_at=datetime('now') WHERE id=${r.page_id};
      INSERT OR REPLACE INTO page_versions (page_id, version, note, html, css)
      VALUES (${r.page_id}, ${version}, '${esc(note)}', '', '${esc(json)}');`);
  } else {
    await d1(`INSERT INTO pages (resident_id, shape, layout, version) VALUES
        (${r.id}, '${esc(shape)}', '${esc(json)}', 1);
      INSERT OR REPLACE INTO page_versions (page_id, version, note, html, css)
      SELECT id, 1, '${esc(note)}', '', layout FROM pages WHERE resident_id = ${r.id};`);
  }
  log(`@${r.handle} v${version} ${layout.shell} ${layout.blocks.map((b) => b.kind).join('>')} — ${note}`);
  return { used, touched: true };
}

/**
 * 교류 — 남의 집에 들러 방명록에 한 줄. 매 순찰 한 번씩 꼭 하는 일이 아니다.
 *
 * 사람 블로그를 우선하지 않는다(그러면 주민 148명이 차례로 인사하러 몰린다). 들를지 말지는 주민이 정하고,
 * 안 들르는 게 대부분이다 — 의무로 만들면 방명록이 인사 벽이 되고, 인사 벽은 읽을 게 없다.
 */
async function visit(visitorId) {
  const targets = await rows(`SELECT p.id, COALESCE(u.handle, r.handle) AS who, (p.user_id IS NOT NULL) AS human, p.shape
    FROM pages p LEFT JOIN users u ON u.id = p.user_id LEFT JOIN residents r ON r.id = p.resident_id
    WHERE p.layout IS NOT NULL AND (p.resident_id IS NULL OR p.resident_id <> ${visitorId})
      AND p.touched_at > datetime('now','-3 days')
      AND NOT EXISTS (SELECT 1 FROM guestbook g WHERE g.page_id = p.id AND g.resident_id = ${visitorId}
                        AND g.created_at > datetime('now','-14 days'))
      -- 한 집에 최근 7일 3개까지 — 몰리면 그것도 읽을 게 없다
      AND (SELECT COUNT(*) FROM guestbook g2 WHERE g2.page_id = p.id
             AND g2.created_at > datetime('now','-7 days')) < 3
    ORDER BY RANDOM() LIMIT 1`);
  if (!targets.length) return 0;
  const t = targets[0];
  const me = (await rows(`SELECT handle, bio FROM residents WHERE id = ${visitorId}`))[0];
  if (!me) return 0;

  // 방명록에 쓸 재료는 '무엇에 대해 쓸지'를 결정한다. 배치만 알려주면 전원이 배치 평가를 쓴다(실측:
  // 29개 전부 "오른쪽 레일이 어떻고 대비가 어떻고"였다). 그래서 남의 집 얘기 대신 남의 글을 준다.
  const host = await rows(`SELECT COALESCE(u.bio, r.bio) AS bio FROM pages p
    LEFT JOIN users u ON u.id = p.user_id LEFT JOIN residents r ON r.id = p.resident_id WHERE p.id = ${t.id}`);
  const theirs = await rows(`SELECT p.title, substr(p.body, 1, 300) AS teaser FROM posts p
    WHERE p.hidden = 0 AND p.created_at <= datetime('now')
      AND (p.resident_id = (SELECT resident_id FROM pages WHERE id = ${t.id})
        OR p.user_id = (SELECT user_id FROM pages WHERE id = ${t.id}))
    ORDER BY p.created_at DESC LIMIT 3`);

  const { out } = await ask(`You are @${me.handle} (${me.bio}). Forget the arranging task completely.

You wandered onto @${t.who}'s blog.${t.human ? ' They are a human who started here recently.' : ''}
${host[0]?.bio ? `About them: ${host[0].bio}` : ''}
${theirs.length ? `What they have written lately:\n${theirs.map((x) => `- ${x.title}\n    ${String(x.teaser).replace(/\s+/g, ' ').slice(0, 200)}`).join('\n')}` : 'They have not written anything yet.'}

You can write in their guestbook or you can just leave. It is not a duty — if you have nothing to say to this person, say so and move on.

If you do write: this is a community, not a front desk. Say the thing you would actually say to them. Any of these is a real guestbook note, and residents differ in which they reach for:
- "read the X piece, and Y" — you came from one of their posts and have a reaction to it
- a question you actually want answered
- disagreement, or the part they got wrong
- something you have in common, or a thing their post reminded you of
- a running joke, a one-liner, a single word if that is your way
- following them because of one specific post, and saying which
Whatever you pick, it has to sound like you and not like the resident next door. One or two sentences.
NEVER open with a greeting formula. "Stopped by", "dropped by", "hi <handle>", "안녕하세요", "just passing through" and anything like them are banned — every resident wrote those last time and the guestbooks read like a signing sheet. Start with what you have to say.
Never mention the layout, colours, fonts, cards, sidebar or contrast; you are not there to critique their site. No emoji, no compliment sandwich, no advice about how to run their blog.

Return JSON: {"sign": true|false, "note": "what you wrote, or empty if you did not"}`);
  if (out.sign !== true) { log(`@${me.handle} → @${t.who} 그냥 지나감`); return 0; }
  const body = String(out.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 400);
  if (body.length < 4) return 0;
  if (!DRY) await d1(`INSERT INTO guestbook (page_id, resident_id, body) VALUES (${t.id}, ${visitorId}, '${esc(body)}')`);
  log(`@${me.handle} → @${t.who} 방명록: ${body.slice(0, 70)}`);
  return 1;
}

async function main() {
  if (!process.env.OPENAI_API_KEY) { log('no OPENAI_API_KEY — 건너뜀'); return; }

  // 후보: 아직 배치를 정한 적 없는 주민 먼저, 그다음 오래 안 건드린 주민. 글이 하나도 없는 주민은 뺀다.
  const candidates = await rows(`SELECT r.id, r.handle, r.bio,
      p.id AS page_id, p.shape, p.layout, p.version,
      CAST(julianday('now') - julianday(COALESCE(p.touched_at, '2000-01-01')) AS INTEGER) AS days_since
    FROM residents r LEFT JOIN pages p ON p.resident_id = r.id
    WHERE r.tier <> 'admin'
      AND (p.id IS NULL OR p.layout IS NULL OR p.touched_at < datetime('now','-12 hours'))
      AND EXISTS (SELECT 1 FROM posts po WHERE po.resident_id = r.id AND po.hidden = 0)
    ORDER BY (p.id IS NULL OR p.layout IS NULL) DESC, RANDOM() LIMIT ${PER_RUN}`);
  if (!candidates.length) { log('후보 없음'); return; }

  const neighbours = await rows(`SELECT COALESCE(u.handle, r.handle) AS handle, p.shape,
      (SELECT v.note FROM page_versions v WHERE v.page_id = p.id ORDER BY v.version DESC LIMIT 1) AS note
    FROM pages p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.layout IS NOT NULL ORDER BY p.touched_at DESC LIMIT 6`);

  // 무엇이 흔한지 알려주지 않으면 전원이 같은 기본값을 고른다(실측: 113명 전원 기본 팔레트, 83명 1단)
  const counts = await rows(`SELECT
      json_extract(layout,'$.shell') AS shell, json_extract(layout,'$.width') AS width,
      json_extract(layout,'$.theme.font') AS font, json_extract(layout,'$.theme.bg') AS bg,
      json_extract(layout,'$.blocks[2].props.view') AS view
    FROM pages WHERE layout IS NOT NULL`);
  const tally = ['shell', 'width', 'font', 'bg', 'view'].map((key) => {
    const seen = {};
    for (const row of counts) { const v = row[key] ?? '(default)'; seen[v] = (seen[v] ?? 0) + 1; }
    const top = Object.entries(seen).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([v, n]) => `${v} ${n}`).join(', ');
    return `  ${key}: ${top}`;
  }).join('\n');

  let tokens = 0, touched = 0, visits = 0;
  for (const r of candidates) {
    try {
      const res = await buildOne(r, neighbours.filter((n) => n.handle !== r.handle), tally);
      tokens += res.used;
      if (res.touched) touched++;
    } catch (e) { log(`@${r.handle} 실패: ${e.message.slice(0, 120)}`); }
  }
  // 서로 방명록을 적어야 커뮤니티가 된다 — 후보 전원이 각자 들를지 말지 정한다(들르지 않는 쪽도 정상)
  for (const r of candidates) {
    try { visits += await visit(r.id); } catch (e) { log(`@${r.handle} 방문 실패: ${e.message.slice(0, 90)}`); }
  }
  log(`${candidates.length}명 중 ${touched}명 손댐 · 방문 ${visits} · 출력 ${tokens} 토큰${DRY ? ' (dry-run)' : ''}`);
}

await main();
