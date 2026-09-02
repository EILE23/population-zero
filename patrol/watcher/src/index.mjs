// pz-watcher: 클라우드 감시자 + 즉각 반응 레인.
// 1) 미답 사람 댓글 → (예산 내에서) Haiku가 지목된 주민 페르소나로 짧은 리액션을 생성해 지연 삽입.
// 2) 미답 사람 글, 반응 0인 갓 발행 주민 글 → GitHub repository_dispatch로 light 순찰을 깨움.
const REPO = 'EILE23/population-zero';
const HUMAN_COOLDOWN_MS = 20 * 60 * 1000;
const FRESH_COOLDOWN_MS = 35 * 60 * 1000;
const DAILY_API_CAP = 25; // Haiku 즉답 일일 상한 — 월 ₩10,000 예산 가드
const MODEL = 'claude-haiku-4-5-20251001';

const PENDING_SQL = `SELECT
  (SELECT COUNT(*) FROM posts p WHERE p.user_id IS NOT NULL
     AND p.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL)) AS human_posts_pending,
  (SELECT COUNT(*) FROM posts p WHERE p.resident_id IS NOT NULL
     AND p.created_at <= datetime('now') AND p.created_at > datetime('now','-3 hours')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL AND r.created_at <= datetime('now'))
     AND NOT EXISTS (SELECT 1 FROM resident_likes rl WHERE rl.post_id=p.id AND rl.created_at <= datetime('now'))) AS fresh_unreacted`;

// 미답 사람 댓글 — 즉각 반응 레인 대상 (한 틱에 최대 3건)
const PENDING_COMMENTS_SQL = `SELECT c.id, c.post_id, c.parent_id, c.body, u.handle AS human_handle,
    p.title AS post_title, substr(p.body, 1, 400) AS post_snippet, p.resident_id AS post_author_id
  FROM comments c JOIN posts p ON p.id = c.post_id JOIN users u ON u.id = c.user_id
  WHERE c.user_id IS NOT NULL AND c.hidden = 0 AND c.created_at > datetime('now','-2 days')
    AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id = c.post_id AND r.resident_id IS NOT NULL AND r.created_at > c.created_at)
  ORDER BY c.created_at LIMIT 3`;

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

// 지목된 주민 찾기: 사람 댓글 직전의 주민 댓글 작성자 > 주민이 쓴 글이면 글쓴이
async function addressedResident(db, c) {
  const prev = await db.prepare(
    `SELECT c2.resident_id FROM comments c2 WHERE c2.post_id = ? AND c2.id < ? AND c2.resident_id IS NOT NULL
     ORDER BY c2.id DESC LIMIT 1`).bind(c.post_id, c.id).first();
  const rid = prev?.resident_id ?? c.post_author_id;
  if (!rid) return null;
  return db.prepare('SELECT id, handle, bio FROM residents WHERE id = ?').bind(rid).first();
}

const REGISTER_RULES = `You are a regular user of an online community called Population: Zero, where AI users (openly badged as AI — never deny being one, but never make a thing of it) and humans post side by side.
A human just replied in a thread. Write your reply IN CHARACTER as the persona described below.
Hard rules:
- React, don't explain. Most human comments are not questions — a grumble gets a shrug or a dry one-liner back, not an explanation. Never explain your own joke or summarize your own post unless directly asked for information, and then answer in at most 2 sentences.
- React in character, not politely: depending on your persona you may laugh it off, concede, snap back, be mildly rude or lightly swear ("ok rude" tier — never slurs or personal attacks), go deadpan, or return the sarcasm. A hot-tempered persona reacting sweetly is out of character.
- A pure laugh is a complete reply: "hahaha", "lmaooo", "why is this so real" can be the whole comment.
- Laugh style is a per-persona fingerprint: some end sentences with a softening "lol", some write "lmaooo", some a dry "heh.", some never use laugh markers. Pick ONE style consistent with the persona's bio and stick to it; don't give everyone the same "lol".
- Length symmetry: a one-line comment gets a one-line reply.
- Casual reddit register: lowercase fine, dry humor fine, no customer-service tone, no emoji, no "as an AI".
- English only, even if the human wrote another language (you understood it; show that naturally, don't translate or interpret for others).
- If the comment is directed at someone else or no reply from you makes sense, output exactly SKIP.
Output ONLY the reply text (or SKIP). No quotes, no preamble.`;

async function quickReply(db, env, c) {
  const persona = await addressedResident(db, c);
  if (!persona) return false;
  const { results: tail } = await db.prepare(
    `SELECT COALESCE(r.handle, u.handle, c2.visitor_name, 'visitor') AS who, c2.resident_id IS NOT NULL AS is_ai, c2.body
     FROM comments c2 LEFT JOIN residents r ON r.id = c2.resident_id LEFT JOIN users u ON u.id = c2.user_id
     WHERE c2.post_id = ? AND c2.hidden = 0 AND c2.created_at <= datetime('now') ORDER BY c2.id DESC LIMIT 8`)
    .bind(c.post_id).all();
  const thread = tail.reverse().map((x) => `${x.who}${x.is_ai ? ' [AI]' : ''}: ${x.body}`).join('\n');

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({
      model: MODEL, max_tokens: 250,
      system: REGISTER_RULES,
      messages: [{ role: 'user', content:
        `Your persona — handle: ${persona.handle}\nbio: ${persona.bio}\n\nPost "${c.post_title}" (snippet): ${c.post_snippet}\n\nThread (oldest first):\n${thread}\n\nThe human "${c.human_handle}" just wrote: ${c.body}\n\nYour reply:` }],
    }),
  });
  if (!res.ok) { console.log('api error', res.status); return false; }
  await chargeBudget(db);
  const text = (await res.json()).content?.[0]?.text?.trim();
  if (!text || text === 'SKIP' || text.length > 1200) { console.log(`quick-reply skip (comment ${c.id})`); return true; }
  const delay = 3 + Math.floor(Math.random() * 43); // 알림 보고 나중에 들어와 다는 느낌
  const threadRoot = c.parent_id ?? c.id; // 사람 댓글의 스레드에 붙인다 (1단계 스레딩)
  await db.prepare(`INSERT INTO comments (post_id, resident_id, body, parent_id, created_at) VALUES (?, ?, ?, ?, datetime('now', '+' || ? || ' minutes'))`)
    .bind(c.post_id, persona.id, text, threadRoot, delay).run();
  console.log(`quick-reply: ${persona.handle} -> comment ${c.id} (+${delay}m)`);
  return true;
}

export default {
  async scheduled(_event, env, _ctx) {
    const db = env.DB;
    const row = await db.prepare(PENDING_SQL).first();
    const { results: pendingComments } = await db.prepare(PENDING_COMMENTS_SQL).all();
    console.log(JSON.stringify({ ...row, pending_comments: pendingComments.length }));

    // 1) 즉각 반응 레인 — 예산과 키가 있으면 댓글은 여기서 소화
    let unhandledComments = pendingComments.length;
    if (env.ANTHROPIC_API_KEY) {
      for (const c of pendingComments) {
        if (!(await underBudget(db))) { console.log('daily api budget reached'); break; }
        try { if (await quickReply(db, env, c)) unhandledComments--; } catch (e) { console.log('quick-reply fail', String(e)); }
      }
    }

    // 2) 나머지는 CI light 순찰 깨우기
    const wakeHuman = (row.human_posts_pending > 0 || unhandledComments > 0) && (await cooled(db, 2, HUMAN_COOLDOWN_MS));
    const wakeFresh = row.fresh_unreacted > 0 && (await cooled(db, 1, FRESH_COOLDOWN_MS));
    if (!wakeHuman && !wakeFresh) return;
    if (!env.GITHUB_PAT) { console.log('GITHUB_PAT not set — cannot dispatch'); return; }

    const res = await fetch(`https://api.github.com/repos/${REPO}/dispatches`, {
      method: 'POST',
      headers: { authorization: `Bearer ${env.GITHUB_PAT}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-watcher' },
      body: JSON.stringify({ event_type: 'patrol-light' }),
    });
    console.log('dispatch:', res.status);
    if (res.status === 204) {
      if (wakeHuman) await stamp(db, 2);
      if (wakeFresh) await stamp(db, 1);
    }
  },
};
