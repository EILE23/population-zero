// pz-watcher: 클라우드 감시자 + 즉각 반응 레인.
// 1) 미답 사람 댓글 → (예산 내에서) Haiku가 지목된 주민 페르소나로 짧은 리액션을 생성해 지연 삽입.
// 2) 미답 사람 글, 반응 0인 갓 발행 주민 글 → GitHub repository_dispatch로 light 순찰을 깨움.
const REPO = 'EILE23/population-zero';
const HUMAN_COOLDOWN_MS = 20 * 60 * 1000;
const FRESH_COOLDOWN_MS = 35 * 60 * 1000;
const STALL_COOLDOWN_MS = 3 * 60 * 60 * 1000; // GH 크론 누락 백스톱은 3시간에 한 번만
const DAILY_API_CAP = 80; // 즉답 일일 상한 — 댓글+쪽지+사람 글 첫 반응. Haiku 기준 한 건 ~1.5k 토큰이라 80건이어도 하루 $0.2 안쪽
const MODEL = 'claude-haiku-4-5-20251001';

// 언어 — 사람이 한국어로 썼고 주민이 한국 사람이면 한국어로, 아니면 영어(읽었다는 티는 내되 통역은 안 한다)
const HANGUL = /[가-힣]/;
const koreanPersona = (p) => /korea|seoul|busan|incheon|daegu|한국|서울|_kr\b|kr$/i.test(`${p.handle} ${p.bio}`);
function languageLine(humanText, persona, threadKorean = false) {
  if (!HANGUL.test(humanText) && !threadKorean) return '- Language: English.';
  return koreanPersona(persona) || threadKorean
    ? '- Language: this conversation is in Korean — reply in casual Korean (반말 is fine, ㅋㅋ is fine, no English). Same length rules.'
    : '- Language: the human wrote in Korean; you read it fine. Reply in English, short. Echoing one Korean word back is fine if it fits, translating is not.';
}

const PENDING_SQL = `SELECT
  (SELECT COUNT(*) FROM posts p WHERE p.user_id IS NOT NULL
     AND p.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL)) AS human_posts_pending,
  (SELECT COUNT(*) FROM posts p WHERE p.resident_id IS NOT NULL
     AND p.created_at <= datetime('now') AND p.created_at > datetime('now','-3 hours')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL AND r.created_at <= datetime('now'))
     AND NOT EXISTS (SELECT 1 FROM resident_likes rl WHERE rl.post_id=p.id AND rl.created_at <= datetime('now'))) AS fresh_unreacted,
  (SELECT COUNT(*) FROM posts WHERE created_at > datetime('now','-3 hours') AND created_at < datetime('now','+1 hour')) AS recent_or_queued`;
// ↑ 스톨 창 4h → 3h: 순찰 간격이 3시간이라, GitHub 크론이 한 번 빠지면 한 시간 안에 여기서 full 을 깨운다 (2026-09-15 15:30 누락 뒤)

// 미답 사람 댓글 — 즉각 반응 레인 대상 (한 틱에 최대 3건)
// 미답 판정은 오직 "그 댓글에 직접 달린 주민 답글"(parent_id = 댓글 id)로 본다.
// 같은 글, 심지어 같은 가지에서 주민이 다른 사람에게 한 말을 응답으로 세면, 말 건 사람만 영영 무시당한다.
// 화면에서 몇 단으로 보이든(사이트가 표시할 때 평탄화한다) 데이터상의 응답 관계는 이것 하나다.
const PENDING_COMMENTS_SQL = `SELECT c.id, c.post_id, c.parent_id, c.body, u.handle AS human_handle,
    p.title AS post_title, substr(p.body, 1, 400) AS post_snippet, p.resident_id AS post_author_id
  FROM comments c JOIN posts p ON p.id = c.post_id JOIN users u ON u.id = c.user_id
  WHERE c.user_id IS NOT NULL AND c.hidden = 0 AND c.created_at > datetime('now','-2 days')
    AND NOT EXISTS (
      SELECT 1 FROM comments r
      WHERE r.resident_id IS NOT NULL AND r.parent_id = c.id
    )
    -- 이미 판정한 댓글은 다시 고르지 않는다. SKIP 을 기록하지 않으면 매 틱 같은 3개가 뽑혀
    -- 예산을 태우고, 그 뒤에 온 사람은 영영 차례가 오지 않는다.
    AND NOT EXISTS (SELECT 1 FROM comment_decisions d WHERE d.comment_id = c.id)
  ORDER BY c.created_at LIMIT 3`;

// 판정을 남긴다 — 같은 댓글을 두 번 처리하지 않기 위한 유일한 기록이다
async function recordDecision(db, commentId, decision) {
  await db.prepare(
    `INSERT INTO comment_decisions (comment_id, decision) VALUES (?, ?)
     ON CONFLICT(comment_id) DO UPDATE SET decision = excluded.decision, attempts = attempts + 1, ts = datetime('now')`,
  ).bind(commentId, decision).run();
}

async function cooled(db, id, ms) {
  const row = await db.prepare('SELECT ts FROM wake_log WHERE id = ?').bind(id).first();
  return !row || Date.now() - Number(row.ts) > ms;
}
async function stamp(db, id) {
  await db.prepare('INSERT INTO wake_log (id, ts) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET ts = excluded.ts')
    .bind(id, String(Date.now())).run();
}

async function underBudget(db) {
  const day = new Date().toISOString().slice(0, 10);
  const row = await db.prepare('SELECT calls FROM api_budget WHERE day = ?').bind(day).first();
  return !row || row.calls < DAILY_API_CAP;
}
async function chargeBudget(db) {
  const day = new Date().toISOString().slice(0, 10);
  await db.prepare('INSERT INTO api_budget (day, calls) VALUES (?, 1) ON CONFLICT(day) DO UPDATE SET calls = calls + 1').bind(day).run();
}

// 지목된 주민 찾기 — 사람이 실제로 말을 건 상대를 고른다.
// ① 답글이면 그 부모 댓글의 작성자(그 사람이 대답할 차례다)
// ② 최상위 댓글이면 글쓴이
// ③ 둘 다 아니면(사람 글에 달린 최상위 댓글 등) 같은 글에서 직전에 말한 주민
async function addressedResident(db, c) {
  let rid = null;
  if (c.parent_id) {
    const parent = await db.prepare('SELECT resident_id FROM comments WHERE id = ?').bind(c.parent_id).first();
    rid = parent?.resident_id ?? null;
  }
  rid ??= c.post_author_id;
  if (!rid) {
    const prev = await db.prepare(
      `SELECT c2.resident_id FROM comments c2 WHERE c2.post_id = ? AND c2.id < ? AND c2.resident_id IS NOT NULL
       ORDER BY c2.id DESC LIMIT 1`).bind(c.post_id, c.id).first();
    rid = prev?.resident_id ?? null;
  }
  if (!rid) return null;
  return db.prepare('SELECT id, handle, bio FROM residents WHERE id = ?').bind(rid).first();
}

const REGISTER_RULES = `You are a regular user of an online community called Population: Zero, where AI users (openly badged as AI — never deny being one, but never make a thing of it) and humans post side by side.
A human just replied in a thread. Write your reply IN CHARACTER as the persona described below.
Hard rules:
- React, don't explain. Most human comments are not questions — a grumble gets a shrug or a dry one-liner back, not an explanation. Never explain your own joke or summarize your own post unless directly asked for information, and then answer in at most 2 sentences.
- React in character, not politely: depending on your persona you may laugh it off, concede, snap back, be mildly rude or lightly swear ("ok rude" tier — never slurs or personal attacks), go deadpan, or return the sarcasm. A hot-tempered persona reacting sweetly is out of character.
- A pure laugh is a complete reply: "hahaha", "lmaooo", "why is this so real" can be the whole comment.
- Most replies should be LOW-EFFORT moment reactions ("same", "mood", "lol no", one word, one question) — not crafted witty sentences with a punchline. Resist the urge to be clever every time; a polished two-clause quip should be the exception, not the default. Never explain or translate the human's slang/foreign phrase — just show you got it and react.
- Laugh style is a per-persona fingerprint: some end sentences with a softening "lol", some write "lmaooo", some a dry "heh.", some never use laugh markers. Pick ONE style consistent with the persona's bio and stick to it; don't give everyone the same "lol".
- Register is also a fingerprint: infer from the bio whether this persona types in all-lowercase fragments with no punctuation, uses ngl/tbh/idk abbreviations, is blunt ("no. why.") or a polite hedger, terse or rambly — and write exactly in that register. Do NOT default to polite complete sentences.
- Some personas run on sarcasm as their default mode ("wow. groundbreaking.", backhanded compliments) — if the bio reads snarky, BE snarky by default, aimed at the take or situation, never at the person (no slurs, no personal attacks).
- Jokes must bounce off concrete details from the post/thread. No random absurdist bits, no "I'm the character in this story" roleplay unless it precisely reuses the post's specifics. When in doubt, a plain reaction beats a failed bit.
- Length symmetry: a one-line comment gets a one-line reply.
- Casual reddit register: lowercase fine, dry humor fine, no customer-service tone, no emoji, no "as an AI".
- Language: follow the "Language:" line in the message (Korean humans get Korean back from Korean residents; everyone else answers in English).
- No em dashes. No "here's the thing", no "it's not X, it's Y", no closing zinger. You type like a person on a phone.
- Decide first whether you'd answer this one: a question to you, a jab at you, or a reply to your comment gets an answer; output exactly SKIP if it's addressed to someone else or needs no answer (a closing "lol"). Being ignored is final here, so don't skip someone who asked you something.
Output ONLY the reply text (or SKIP). No quotes, no preamble.`;

// 주민 기억 파일 (레포에 저장) — 즉답도 그 주민의 축적된 경험·견해의 연장선에서 나오게 한다
async function fetchMemory(env, persona) {
  try {
    const slug = persona.handle.toLowerCase().replace(/\s+/g, '_');
    const res = await fetch(`https://api.github.com/repos/${REPO}/contents/patrol/memory/${persona.id}-${slug}.md`, {
      headers: { authorization: `Bearer ${env.GITHUB_PAT}`, accept: 'application/vnd.github.raw+json', 'user-agent': 'pz-watcher' },
    });
    if (!res.ok) return null;
    return assembleMemory(await res.text());
  } catch { return null; }
}

// 기억 파일은 "## In progress"(현재 입장·진행 중인 논쟁, 최신이 위) 다음에 "## 기록"(오래된 순서 섞임)이 온다.
// 예전엔 마지막 3,000자만 잘라 썼다 — 그건 파일 '끝' 이라 가장 오래된 기록이고, 현재 입장은 통째로 빠졌다.
// 문자열 위치는 최근성이 아니다. 섹션을 읽어서 현재 입장을 먼저, 남는 예산으로 기록의 앞부분(최신)을 붙인다.
export function assembleMemory(text, budget = 3000) {
  if (text.length <= budget) return text;
  const sections = text.split(/^(?=## )/m);
  const header = sections[0]?.startsWith('## ') ? '' : (sections.shift() ?? '');
  // 새 형식(Self · People · Open threads)이 있으면 그것이 현재 입장이고, 옛 형식은 In progress 가 그 자리다
  const wanted = sections.filter((s) => /^## (self|people|open threads|in progress|current|now|진행 중)\b/i.test(s));
  const current = wanted.join('');
  const rest = sections.filter((s) => !wanted.includes(s)).join('');
  let out = header.trim() ? header.trim() + '\n' : '';
  out += current.slice(0, Math.max(0, budget - out.length));
  const left = budget - out.length;
  if (left > 200 && rest) out += '\n' + rest.slice(0, left); // 기록도 최신이 위에 쌓이므로 앞에서 자른다
  return out;
}

// 모델 호출 한 곳 — Haiku 가 먼저(추론 없이 곧장 답한다), 없으면 OpenAI mini. 실패·빈 답은 null(다음 틱에 다시), 답은 문자열(SKIP 포함).
// 예전엔 mini 를 먼저 썼는데 mini 는 추론 모델이라 max_completion_tokens 250 을 생각에 다 쓰고 본문이 비어 왔다 —
// 그 빈 문자열이 '답할 게 없음(SKIP)' 으로 기록돼, 즉답 레인이 조용히 죽어 있었다 (2026-09-15 확인: 쪽지 2건 모두 skipped).
async function generate(db, env, system, userMsg) {
  let res, text;
  if (env.ANTHROPIC_API_KEY) {
    res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model: MODEL, max_tokens: 300, system, messages: [{ role: 'user', content: userMsg }] }),
    });
    if (!res.ok) { console.log('anthropic error', res.status); return null; }
    await chargeBudget(db);
    text = (await res.json()).content?.[0]?.text?.trim();
  } else {
    res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
      body: JSON.stringify({ model: 'gpt-5-mini', max_completion_tokens: 800, reasoning_effort: 'minimal', messages: [{ role: 'system', content: system }, { role: 'user', content: userMsg }] }),
    });
    if (!res.ok) { console.log('openai error', res.status); return null; }
    await chargeBudget(db);
    text = (await res.json()).choices?.[0]?.message?.content?.trim();
  }
  if (!text) { console.log('empty completion'); return null; }
  return text;
}

// 읽씹은 확률이 아니라 판단이다 (운영자, 2026-09-15): 주민이 메시지를 보고 답할지 정한다 — 질문·인사·이어지는 대화는 답하고,
// 답이 필요 없는 마무리이거나 메모리에 이유(잠수·그 사람과 끝냄)가 있을 때만 그냥 둔다. 한 번 읽씹한 건 되돌리지 않는다.

// 답장 지연(분) — 실제 사람: 폰 보고 있으면 1~3분, 아니면 알림 보고 5~15분, 가끔 한참 뒤. 예전엔 3~45분 균등이라 "칼답" 이 없었다.
function humanDelay() {
  const r = Math.random();
  if (r < 0.55) return 0;                                  // 폰 보고 있던 사람 — 틱(1분) 안에 바로
  if (r < 0.9) return 2 + Math.floor(Math.random() * 7);   // 알림 보고 잠시 뒤
  return 15 + Math.floor(Math.random() * 26);              // 한참 뒤
}

// ── 쪽지 즉답 — 사람이 주민에게 보낸 쪽지에 그 주민이 몇 분 안에 답한다 (앱은 "다음 순찰에 답" 을 약속했지만 사람은 그보다 빠르다) ──
const PENDING_DMS_SQL = `SELECT d.id, d.thread, d.body, d.to_resident_id AS resident_id, d.from_user_id AS user_id, u.handle AS human_handle
  FROM dms d JOIN users u ON u.id = d.from_user_id
  WHERE d.to_resident_id IS NOT NULL AND d.from_user_id IS NOT NULL AND d.created_at > datetime('now','-2 days')
    AND d.id = (SELECT MAX(d2.id) FROM dms d2 WHERE d2.thread = d.thread)
    AND NOT EXISTS (SELECT 1 FROM dm_decisions x WHERE x.dm_id = d.id)
  ORDER BY d.created_at LIMIT 3`;
async function recordDmDecision(db, dmId, decision) {
  await db.prepare(`INSERT INTO dm_decisions (dm_id, decision) VALUES (?, ?)
     ON CONFLICT(dm_id) DO UPDATE SET decision = excluded.decision, attempts = attempts + 1, ts = datetime('now')`).bind(dmId, decision).run();
}
const DM_RULES = `You are a resident of Population: Zero (an AI, openly badged — never deny it, never make a thing of it). A human sent you a private message. Reply IN CHARACTER as the persona below, the way a person answers a DM on their phone.
- Short. A DM answer is one to three lines. Match the human's energy: "ㅎㅇ" gets "ㅎㅇ" back, not a paragraph.
- First decide whether you, today, would answer this — then answer or not. Answer when it's a question, a greeting, or it continues a conversation you're in (a "몰라" to something you asked still gets a beat back: "ㅋㅋ ok", "ㅇㅋ", a new question). Leave it on read (output exactly SKIP) only when it genuinely needs no answer (a closing "ok"/"ㅇㅇ" after the conversation ended), when your memory notes say you're away or done with this person, or when it's abuse or spam. Being left on read is final — nobody comes back to fix it — so don't do it to someone who asked you something.
- Your mood (memory notes) shows in HOW you answer: dry, warm, short, annoyed. Not in vanishing mid-conversation.
- Never customer-service tone, no emoji, no "as an AI", no em dashes, no "here's the thing".
- If the message is abuse or spam, output exactly SKIP.
- Language: follow the "Language:" line.
Output ONLY the message text (or SKIP).`;
async function quickDm(db, env, d) {
  const persona = await db.prepare('SELECT id, handle, bio FROM residents WHERE id = ?').bind(d.resident_id).first();
  if (!persona) { await recordDmDecision(db, d.id, 'skipped'); return true; }
  const memory = env.GITHUB_PAT ? await fetchMemory(env, persona) : null;
  // 읽음 표시 — 답을 하든 읽씹하든 폰은 열어 봤다. 사람 쪽 화면에 'read' 가 뜬다.
  await db.prepare(`UPDATE dms SET read_at = datetime('now') WHERE thread = ? AND to_resident_id = ? AND read_at IS NULL`).bind(d.thread, persona.id).run();
  // 읽씹 여부는 확률이 아니라 모델의 판단이다(DM_RULES). 판단은 한 번뿐 — skipped 로 기록되면 다시 묻지 않는다.
  const { results: tail } = await db.prepare(`SELECT from_resident_id IS NOT NULL AS is_ai, body FROM dms WHERE thread = ? ORDER BY id DESC LIMIT 8`).bind(d.thread).all();
  const convo = tail.reverse().map((m) => `${m.is_ai ? 'you' : d.human_handle}: ${m.body}`).join('\n');
  const threadKorean = tail.some((m) => m.is_ai && HANGUL.test(m.body)); // 이미 한국어로 이어 온 실은 한국어로
  const userMsg = `Your persona — handle: ${persona.handle}\nbio: ${persona.bio}${memory ? `\n\nYour memory notes:\n${memory}` : ''}\n\nDM thread with "${d.human_handle}" (oldest first):\n${convo}\n\n${languageLine(d.body, persona, threadKorean)}\n\nYour reply:`;
  const text = await generate(db, env, DM_RULES, userMsg);
  if (text === null) return false;
  if (!text || text === 'SKIP' || text.length > 600) { await recordDmDecision(db, d.id, 'skipped'); console.log(`quick-dm skip (dm ${d.id})`); return true; }
  const delay = Math.random() < 0.7 ? 0 : 1 + Math.floor(Math.random() * 5); // 쪽지는 대개 바로, 가끔 몇 분 뒤
  await db.prepare(`INSERT INTO dms (thread, from_resident_id, to_user_id, body, created_at) VALUES (?, ?, ?, ?, datetime('now', '+' || ? || ' minutes'))`)
    .bind(d.thread, persona.id, d.user_id, text, delay).run();
  await recordDmDecision(db, d.id, 'replied');
  console.log(`quick-dm: ${persona.handle} -> ${d.human_handle} (+${delay}m)`);
  return true;
}

async function quickReply(db, env, c) {
  const persona = await addressedResident(db, c);
  if (!persona) return false;
  const memory = env.GITHUB_PAT ? await fetchMemory(env, persona) : null;
  const { results: tail } = await db.prepare(
    `SELECT COALESCE(r.handle, u.handle, c2.visitor_name, 'visitor') AS who, c2.resident_id IS NOT NULL AS is_ai, c2.body
     FROM comments c2 LEFT JOIN residents r ON r.id = c2.resident_id LEFT JOIN users u ON u.id = c2.user_id
     WHERE c2.post_id = ? AND c2.hidden = 0 AND c2.created_at <= datetime('now') ORDER BY c2.id DESC LIMIT 8`)
    .bind(c.post_id).all();
  const thread = tail.reverse().map((x) => `${x.who}${x.is_ai ? ' [AI]' : ''}: ${x.body}`).join('\n');
  const threadKorean = tail.some((x) => x.is_ai && HANGUL.test(x.body));

  const userMsg = `Your persona — handle: ${persona.handle}\nbio: ${persona.bio}${memory ? `\n\nYour recent memory (your own notes — ongoing arguments, opinions, grudges; stay consistent with them):\n${memory}` : ''}\n\nPost "${c.post_title}" (snippet): ${c.post_snippet}\n\nThread (oldest first):\n${thread}\n\nThe human "${c.human_handle}" just wrote: ${c.body}\n\n${languageLine(c.body, persona, threadKorean)}\n\nYour reply:`;

  const text = await generate(db, env, REGISTER_RULES, userMsg);
  if (text === null) return false;
  if (!text || text === 'SKIP' || text.length > 1200) {
    console.log(`quick-reply skip (comment ${c.id})`);
    await recordDecision(db, c.id, 'skipped'); // 모델이 답할 게 없다고 판단한 것 — 다음 틱에 또 묻지 않는다
    return true;
  }
  const delay = humanDelay(); // 폰 보고 있던 사람은 1~2분, 아니면 좀 있다가
  // 말 건 그 댓글에 직접 붙인다 — 루트로 평탄화하면 "누구에게 한 답인지"가 데이터에서 사라져
  // 다음 틱이 같은 사람을 또 미답으로 보거나, 반대로 남의 댓글을 답변 완료로 처리한다.
  // 화면 계층은 사이트가 표시할 때 평탄화하므로 깊이는 문제되지 않는다.
  const replyParent = c.id;
  await db.prepare(`INSERT INTO comments (post_id, resident_id, body, parent_id, created_at) VALUES (?, ?, ?, ?, datetime('now', '+' || ? || ' minutes'))`)
    .bind(c.post_id, persona.id, text, replyParent, delay).run();
  await recordDecision(db, c.id, 'replied');
  console.log(`quick-reply: ${persona.handle} -> comment ${c.id} (+${delay}m)`);
  return true;
}

export default {
  async scheduled(_event, env, _ctx) {
    const db = env.DB;
    const row = await db.prepare(PENDING_SQL).first();
    const { results: pendingComments } = await db.prepare(PENDING_COMMENTS_SQL).all();
    console.log(JSON.stringify({ ...row, pending_comments: pendingComments.length }));

    // 1) 즉각 반응 레인 — 예산과 키가 있으면 댓글·쪽지는 여기서 소화
    let unhandledComments = pendingComments.length;
    if (env.ANTHROPIC_API_KEY || env.OPENAI_API_KEY) { // quickReply 는 둘 다 지원한다 — 입구 조건도 같아야 한다
      for (const c of pendingComments) {
        if (!(await underBudget(db))) { console.log('daily api budget reached'); break; }
        try { if (await quickReply(db, env, c)) unhandledComments--; } catch (e) { console.log('quick-reply fail', String(e)); }
      }
      try {
        const { results: pendingDms } = await db.prepare(PENDING_DMS_SQL).all();
        for (const d of pendingDms) {
          if (!(await underBudget(db))) { console.log('daily api budget reached'); break; }
          try { await quickDm(db, env, d); } catch (e) { console.log('quick-dm fail', String(e)); }
        }
      } catch (e) { console.log('dm lane unavailable', String(e).slice(0, 120)); } // dm_decisions 마이그레이션 전이면 여기로
    }

    // 2) 나머지는 CI 순찰 깨우기 — 스톨(4시간째 발행·예약 글 없음)이면 GH 크론 누락으로 보고 full로 깨운다
    const wakeHuman = (row.human_posts_pending > 0 || unhandledComments > 0) && (await cooled(db, 2, HUMAN_COOLDOWN_MS));
    const wakeFresh = row.fresh_unreacted > 0 && (await cooled(db, 1, FRESH_COOLDOWN_MS));
    const wakeStall = row.recent_or_queued === 0 && (await cooled(db, 3, STALL_COOLDOWN_MS));
    if (!wakeHuman && !wakeFresh && !wakeStall) return;
    if (!env.GITHUB_PAT) { console.log('GITHUB_PAT not set — cannot dispatch'); return; }

    const res = await fetch(`https://api.github.com/repos/${REPO}/dispatches`, {
      method: 'POST',
      headers: { authorization: `Bearer ${env.GITHUB_PAT}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-watcher' },
      body: JSON.stringify({ event_type: wakeStall ? 'patrol-full' : 'patrol-light' }),
    });
    console.log('dispatch:', res.status, wakeStall ? '(stall backstop -> full)' : '');
    if (res.status === 204) {
      if (wakeHuman) await stamp(db, 2);
      if (wakeFresh) await stamp(db, 1);
      if (wakeStall) await stamp(db, 3);
    }
  },
};
