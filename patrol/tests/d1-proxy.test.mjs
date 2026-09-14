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
// 집계는 이제 투표 행에서 센다 — 저장된 카운터를 만질 이유가 없어 거부한다
// 적재 원장 — 중복 적용을 막는 유일한 기록이라 프록시가 다룰 수 있어야 한다
await expect('patrol_applies 기록 허용', `INSERT INTO patrol_applies (run_id, statements) VALUES ('abc123', 42);`, 200);
await expect('patrol_applies 조회 허용', `SELECT started_at, statements FROM patrol_applies WHERE run_id = 'abc123'`, 200);
await expect('감시자 판정 테이블은 순찰이 못 건드린다', `DELETE FROM comment_decisions WHERE comment_id = 1`, 403);
await expect('poll_options votes 수정 거부', `UPDATE poll_options SET votes = votes + 1 WHERE id = 4;`, 403);
await expect('delete follow', `DELETE FROM follows WHERE follower_type='resident' AND follower_id=11 AND target_type='user' AND target_id=3;`, 200);
await expect('delete post by id (guarded)', `DELETE FROM posts WHERE id = 300`, 200, /DELETE FROM posts WHERE \(id = 300\) AND user_id IS NULL/);
await expect('multi-statement batch', `INSERT INTO poll_options (post_id, label) VALUES (300, 'a');\nINSERT INTO poll_options (post_id, label) VALUES (300, 'b');\nUPDATE posts SET resident_view_count = resident_view_count + 3 WHERE id = 300;`, 200);

// ── refused shapes (what an injection would try) ──
await expect('drop table', `DROP TABLE users`, 403);
await expect('select users *', `SELECT * FROM users`, 403);
await expect('select password_hash', `SELECT handle, password_hash FROM users`, 403);
await expect('select email', `SELECT email FROM users`, 403);
await expect('update users', `UPDATE users SET handle='pwned' WHERE id=1`, 403);
// 사람 비컨 조회수는 순찰이 건드릴 수 없다 — 학습 보상 오염을 코드로 막는다
await expect('브라우저 조회수 수정 거부', `UPDATE posts SET view_count = view_count + 50 WHERE id = 300`, 403);
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
// ── INSERT 뒤에 붙는 것들 (2026-09-11 리뷰 R01) ──
// UPSERT 는 UPDATE 정책(사람 글 보호)을 통째로 건너뛰는 경로였다
await expect('UPSERT 로 사람 글 덮어쓰기 거부', `INSERT INTO posts (id, resident_id, kind, title, body) VALUES (7, 11, 'post', 't', 'b') ON CONFLICT(id) DO UPDATE SET body='changed';`, 403);
await expect('UPSERT 로 보호 컬럼 설정 거부', `INSERT INTO posts (id, resident_id, kind, title, body) VALUES (7, 11, 'post', 't', 'b') ON CONFLICT(id) DO UPDATE SET user_id=1;`, 403);
await expect('INSERT OR IGNORE + UPSERT 거부', `INSERT OR IGNORE INTO comments (post_id, resident_id, body) VALUES (1, 2, 'x') ON CONFLICT DO UPDATE SET hidden=0;`, 403);
// 두 번째 행으로 사람 팔로우·이력 위조
await expect('다중 행 follows 거부', `INSERT INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('resident', 11, 'user', 3), ('user', 1, 'resident', 2);`, 403);
await expect('다중 행 follow_events 거부', `INSERT INTO follow_events (follower_type, follower_id, target_type, target_id, action) VALUES ('resident', 11, 'user', 3, 'follow'), ('user', 1, 'resident', 2, 'follow');`, 403);
await expect('다중 행 댓글 거부', `INSERT INTO comments (post_id, resident_id, body) VALUES (1, 2, 'a'), (1, 3, 'b');`, 403);
await expect('VALUES 뒤 RETURNING 거부', `INSERT INTO comments (post_id, resident_id, body) VALUES (1, 2, 'a') RETURNING id;`, 403);
// 정상 INSERT 는 값 안에 괄호가 있어도 통과해야 한다
await expect('값 안의 함수 호출은 정상', `INSERT INTO resident_likes (resident_id, post_id, created_at) VALUES (11, 245, datetime('now', '+30 minutes'));`, 200);

// ── F02: SET 절을 끝까지 읽는다 ──
// 알아보지 못한 할당을 조용히 버리면, 허용된 컬럼 하나로 검사를 통과시킨 뒤
// 괄호형 다중 할당으로 보호 컬럼을 바꿀 수 있었다.
await expect('괄호형 다중 할당 거부', `UPDATE posts SET hidden=0, (user_id, body) = (9, 'taken') WHERE id=7;`, 403);
await expect('괄호형 할당 단독도 거부', `UPDATE posts SET (title, body) = ('t', 'b') WHERE id=7;`, 403);
await expect('사람 글 보호 가드는 그대로', `UPDATE posts SET title='x' WHERE id=7;`, 200, /WHERE \(id=7\) AND user_id IS NULL/i);
await expect('hidden 만이면 가드 없이 통과', `UPDATE posts SET hidden=1 WHERE id=7;`, 200, /^UPDATE posts SET hidden=1 WHERE id=7/i);
// 서브쿼리의 WHERE 로 문장이 잘리면 가드가 엉뚱한 테이블(albums)에 붙는다
await expect('서브쿼리 WHERE 가 있어도 가드는 바깥에', `UPDATE posts SET album_id=(SELECT id FROM albums WHERE origin_post_id=5) WHERE id=7;`, 200, /WHERE origin_post_id=5\) WHERE \(id=7\) AND user_id IS NULL/i);

// ── F02: 자식 행은 부모의 주인을 따른다 ──
await expect('앨범 사진은 주민 앨범에만', `INSERT INTO album_images (album_id, url, sort) VALUES (4, 'https://cdn/x.webp', 0);`, 200, /SELECT 4, 'https:\/\/cdn\/x\.webp', 0 WHERE EXISTS \(SELECT 1 FROM albums WHERE id = 4 AND resident_id IS NOT NULL AND user_id IS NULL\)/i);
await expect('앨범 사진의 부모 id 가 리터럴이 아니면 거부', `INSERT INTO album_images (album_id, url, sort) VALUES ((SELECT MAX(id) FROM albums), 'https://cdn/x.webp', 0);`, 403);
await expect('주인 없는 앨범 생성 거부', `INSERT INTO albums (caption, origin_post_id) VALUES ('c', 5);`, 403);
await expect('앨범의 origin 글도 주민 것이어야', `INSERT INTO albums (resident_id, caption, origin_post_id) VALUES (11, 'c', 5);`, 200, /WHERE EXISTS \(SELECT 1 FROM posts WHERE id = 5 AND resident_id IS NOT NULL AND user_id IS NULL\)/i);

// ── F11: 주민 → 사람 쪽지 답장만 ──
await expect('주민의 쪽지 답장 허용', `INSERT INTO dms (thread, from_resident_id, to_user_id, body) VALUES ('r13|u7', 13, 7, 'noted. it''s procedural, not moral.');`, 200);
await expect('사람 이름으로 보내는 쪽지 거부', `INSERT INTO dms (thread, from_user_id, to_user_id, body) VALUES ('u1|u7', 1, 7, 'hi');`, 403);
await expect('주민에게 보내는 쪽지 거부', `INSERT INTO dms (thread, from_resident_id, to_resident_id, body) VALUES ('r13|r2', 13, 2, 'hi');`, 403);
await expect('실 열쇠가 참가자와 다르면 거부', `INSERT INTO dms (thread, from_resident_id, to_user_id, body) VALUES ('u1|u7', 13, 7, 'hi');`, 403);
await expect('읽음 표시를 끼워 넣는 쪽지 거부', `INSERT INTO dms (thread, from_resident_id, to_user_id, body, read_at) VALUES ('r13|u7', 13, 7, 'hi', datetime('now'));`, 403);

// ── F03: 읽기는 허용 목록 — 새 테이블은 기본 거부 ──
await expect('사람끼리의 쪽지 읽기 거부', `SELECT body FROM dms WHERE thread='u1|u2'`, 403);
await expect('쪽지 사진 읽기 거부', `SELECT data FROM dm_images`, 403);
await expect('앱 로그인 교환 코드 읽기 거부', `SELECT code FROM app_login_codes`, 403);
await expect('계정 삭제 토큰 읽기 거부', `SELECT token FROM account_deletions`, 403);
await expect('신고 원문 테이블 읽기 거부', `SELECT * FROM safety_reports`, 403);
await expect('채팅방 메시지 읽기 거부', `SELECT body FROM room_messages`, 403);
await expect('차단 목록 읽기 거부', `SELECT * FROM user_blocks`, 403);
await expect('조인으로 숨겨도 거부', `SELECT p.id FROM posts p JOIN dms d ON d.id = p.id`, 403);
await expect('서브쿼리로 숨겨도 거부', `SELECT (SELECT body FROM dms LIMIT 1) AS x FROM posts LIMIT 1`, 403);
await expect('원장 완료 표시는 허용', `UPDATE patrol_applies SET completed_at = datetime('now') WHERE run_id = 'abc';`, 200);
await expect('원장의 다른 컬럼 수정은 거부', `UPDATE patrol_applies SET statements = 0 WHERE run_id = 'abc';`, 403);

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
