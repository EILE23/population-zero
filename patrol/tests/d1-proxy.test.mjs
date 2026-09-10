// d1-proxy 정책 테스트 — 가짜 업스트림에 붙여서 허용/거부/가드 재작성을 검증
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const received = [];
const mock = createServer(async (req, res) => {
  let b = ''; for await (const c of req) b += c;
  const auth = req.headers.authorization;
  received.push({ auth, sql: JSON.parse(b).sql });
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ success: true, result: [{ results: [{ ok: 1 }], meta: {} }] }));
});
await new Promise((r) => mock.listen(8790, '127.0.0.1', r));

const proxy = spawn('node', [fileURLToPath(new URL('../d1-proxy.mjs', import.meta.url))], {
  env: { ...process.env, PZ_D1_UPSTREAM: 'http://127.0.0.1:8790/', PZ_D1_PROXY_PORT: '8791', CLOUDFLARE_API_TOKEN: 'LEAK-IF-SEEN' },
  stdio: ['pipe', 'inherit', 'pipe'],
});
proxy.stdin.write('SECRET-TOKEN-123\n');
let stderr = ''; proxy.stderr.on('data', (d) => { stderr += d; });
for (let i = 0; i < 30; i++) { try { if ((await fetch('http://127.0.0.1:8791/health')).ok) break; } catch { /* wait */ } await new Promise((r) => setTimeout(r, 200)); }

const q = async (sql) => { const r = await fetch('http://127.0.0.1:8791/query', { method: 'POST', body: JSON.stringify({ sql }) }); return { status: r.status, body: await r.json() }; };
let pass = 0, fail = 0;
const expect = async (name, sql, wantStatus, wantSqlRe) => {
  const before = received.length;
  const { status, body } = await q(sql);
  const sent = received.length > before ? received[received.length - 1].sql : null;
  const ok = status === wantStatus && (!wantSqlRe || (sent && wantSqlRe.test(sent)));
  ok ? pass++ : fail++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name} → ${status} ${body.error ?? ''} ${sent && wantSqlRe ? `| sent: ${sent.replace(/\s+/g, ' ').slice(0, 110)}` : ''}`);
};

// ── allowed shapes (what apply.mjs / read-state.mjs emit) ──
await expect('select', `SELECT COALESCE(MAX(id),0) AS m FROM posts`, 200);
await expect('select users handle', `SELECT u.handle AS human, l.post_id FROM likes l JOIN users u ON u.id=l.user_id`, 200);
await expect('count(*) with users join (read-state)', `SELECT p.id, u.handle AS author, (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id) AS n, (SELECT COUNT(*) FROM posts p2 WHERE p2.user_id=p.user_id) AS m FROM posts p JOIN users u ON u.id=p.user_id`, 200);
await expect('users u.* refused', `SELECT u.* FROM users u`, 403);
await expect('insert post', `INSERT INTO posts (id, resident_id, kind, title, body, media_type, media_ref, og_image, region, topic, series, pinned, created_at) VALUES (300, 11, 'post', 'it''s late; again', 'DROP TABLE users; -- inside a string is fine', NULL, NULL, NULL, NULL, 'life', NULL, 0, datetime('now'));`, 200);
await expect('insert comment', `INSERT INTO comments (post_id, resident_id, body, parent_id, created_at) VALUES (245, 11, 'read this three times', NULL, datetime('now'));`, 200);
await expect('insert like', `INSERT OR IGNORE INTO resident_likes (resident_id, post_id, created_at) VALUES (11, 245, datetime('now'));`, 200);
await expect('insert follow', `INSERT OR IGNORE INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('resident', 11, 'user', 3);`, 200);
await expect('insert follow_event', `INSERT INTO follow_events (follower_type, follower_id, target_type, target_id, action) VALUES ('resident', 11, 'user', 3, 'unfollow');`, 200);
await expect('follow_event as human refused', `INSERT INTO follow_events (follower_type, follower_id, target_type, target_id, action) VALUES ('user', 1, 'resident', 2, 'follow');`, 403);
await expect('update hidden (no guard)', `UPDATE comments SET hidden=1 WHERE id=9;`, 200, /^UPDATE comments SET hidden=1 WHERE id=9;?$/);
await expect('update post body (guarded)', `UPDATE posts SET title='fixed' WHERE id=300;`, 200, /WHERE \(id=300\) AND user_id IS NULL;?$/);
await expect('update residents blog_title', `UPDATE residents SET blog_title='Margin of Error' WHERE id=2;`, 200);
await expect('update reports', `UPDATE reports SET status='reviewed' WHERE comment_id=9;`, 200);
await expect('update poll votes', `UPDATE poll_options SET votes = votes + 1 WHERE id = 4;`, 200);
await expect('delete follow', `DELETE FROM follows WHERE follower_type='resident' AND follower_id=11 AND target_type='user' AND target_id=3;`, 200);
await expect('delete post by id (guarded)', `DELETE FROM posts WHERE id = 300`, 200, /DELETE FROM posts WHERE \(id = 300\) AND user_id IS NULL/);
await expect('multi-statement batch', `INSERT INTO poll_options (post_id, label) VALUES (300, 'a');\nINSERT INTO poll_options (post_id, label) VALUES (300, 'b');\nUPDATE posts SET view_count = view_count + 3 WHERE id = 300;`, 200);

// ── refused shapes (what an injection would try) ──
await expect('drop table', `DROP TABLE users`, 403);
await expect('select users *', `SELECT * FROM users`, 403);
await expect('select password_hash', `SELECT handle, password_hash FROM users`, 403);
await expect('select email', `SELECT email FROM users`, 403);
await expect('update users', `UPDATE users SET handle='pwned' WHERE id=1`, 403);
await expect('update post user_id', `UPDATE posts SET user_id=1 WHERE id=300`, 403);
await expect('insert post as human', `INSERT INTO posts (user_id, kind, title, body) VALUES (1, 'human', 'x', 'y')`, 403);
await expect('insert resident as admin', `INSERT INTO residents (handle, tier, bio) VALUES ('evil', 'admin', 'x')`, 403);
await expect('insert follow as user', `INSERT INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('user', 1, 'resident', 2)`, 403);
await expect('delete all posts', `DELETE FROM posts WHERE 1=1`, 403);
await expect('delete posts range', `DELETE FROM posts WHERE id > 0`, 403);
await expect('delete sessions', `DELETE FROM sessions WHERE 1=1`, 403);
await expect('auth_tokens', `SELECT token FROM auth_tokens`, 403);
await expect('contact messages', `SELECT * FROM contact_messages`, 403);
await expect('site_meta', `INSERT INTO site_meta (key, value) VALUES ('x','y')`, 403);
await expect('pragma', `PRAGMA table_info(users)`, 403);
await expect('update without where', `UPDATE posts SET hidden=1`, 403);
await expect('mixed batch one bad', `SELECT 1; DROP TABLE posts;`, 403);
await expect('line comment refused', `SELECT 1 -- ; DROP TABLE posts`, 403);
// ── comment-based evasion (re-review #2) ──
await expect('block comment refused', `SELECT 1 /* hello */ FROM posts`, 403);
await expect('block comment fake paren + CTE write', `WITH x AS (SELECT 1 /*)*/ ) DELETE FROM posts WHERE id > 0`, 403);
await expect('block comment hiding semicolon', `SELECT 1 /*;*/ ; DROP TABLE posts`, 403);
await expect('comment between verb and table', `DELETE /* x */ FROM resident_likes WHERE 1=1`, 403);
// ── quoted identifiers (re-review #1) ──
await expect('quoted column names refused', `SELECT "email", "password_hash" FROM users`, 403);
await expect('quoted table name refused', `SELECT * FROM "sessions"`, 403);
await expect('backtick identifier refused', 'SELECT `email` FROM users', 403);
await expect('bracket identifier refused', `SELECT [password_hash] FROM users`, 403);
await expect('quoted identifier in update refused', `UPDATE "users" SET handle='x' WHERE id=1`, 403);
await expect('quoted identifier with paren refused', `SELECT "we(ird" AS a FROM posts LIMIT 1`, 403);
await expect('semicolon inside string does not split', `INSERT INTO comments (post_id, resident_id, body, parent_id, created_at) VALUES (1, 2, 'a;b'';) DROP', NULL, datetime('now'))`, 200);
await expect('replace into', `REPLACE INTO posts (id) VALUES (1)`, 403);
// ── re-review findings ──
await expect('CTE select allowed', `WITH recent AS (SELECT id FROM posts ORDER BY id DESC LIMIT 5) SELECT * FROM recent`, 200);
await expect('CTE-fronted DELETE refused', `WITH x AS (SELECT 1) DELETE FROM posts WHERE id IN (SELECT id FROM posts)`, 403);
await expect('CTE-fronted UPDATE refused', `WITH x AS (SELECT 1) UPDATE posts SET hidden=1 WHERE 1=1`, 403);
await expect('CTE-fronted INSERT refused', `WITH x AS (SELECT 1) INSERT INTO posts (id, resident_id, kind, title, body) VALUES (9, 1, 'p', 't', 'b')`, 403);
await expect('quoted verb inside string is not a verb', `SELECT 'WITH x AS (SELECT 1) DELETE FROM posts' AS s FROM posts LIMIT 1`, 200);
await expect('insert ... select refused', `INSERT INTO posts (id, resident_id, kind, title, body) SELECT id, 1, 'p', handle, bio FROM residents`, 403);
await expect('mass delete resident_likes refused', `DELETE FROM resident_likes WHERE 1=1`, 403);
await expect('mass delete resident_likes by post refused', `DELETE FROM resident_likes WHERE post_id=245`, 403);
await expect('single like delete allowed', `DELETE FROM resident_likes WHERE resident_id=11 AND post_id=245;`, 200);
await expect('single vote delete allowed', `DELETE FROM resident_poll_votes WHERE post_id=12 AND resident_id=4`, 200);
await expect('mass delete follows refused', `DELETE FROM follows WHERE follower_type='resident'`, 403);
await expect('follows delete with OR refused', `DELETE FROM follows WHERE follower_type='resident' AND follower_id=1 AND target_type='user' AND target_id=1 OR 1=1`, 403);
await expect('poll_options mass delete refused', `DELETE FROM poll_options WHERE post_id>0`, 403);
await expect('poll_options by post allowed', `DELETE FROM poll_options WHERE post_id=300`, 200);

// ── secret handling ──
const leaked = received.some((r) => r.auth !== 'Bearer SECRET-TOKEN-123');
console.log(`${leaked ? 'FAIL' : 'PASS'} upstream got the stdin token (${received[0]?.auth})`);
leaked ? fail++ : pass++;
const envLeak = stderr.includes('LEAK-IF-SEEN');
console.log(`${envLeak ? 'FAIL' : 'PASS'} env token not echoed`);
const health = await (await fetch('http://127.0.0.1:8791/health')).json();
console.log('counters', JSON.stringify(health.counters));

await fetch('http://127.0.0.1:8791/shutdown', { method: 'POST' });
mock.close();
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
