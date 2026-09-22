// 감시자의 미답 사람 글 선별 — 답이 다 붙은 최신 글 5개 뒤에 있는 미답 질문이 대상이 되어야 한다.
// 예전엔 `ORDER BY created_at DESC LIMIT 5` 를 먼저 자르고 JS 에서 걸러서, 그 질문은 어느 틱에서도 뽑히지 않았다.
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { PENDING_HUMAN_POSTS_SQL } from '../watcher/src/index.mjs';

const db = new DatabaseSync(':memory:');
db.exec(`
  CREATE TABLE users (id INTEGER PRIMARY KEY, handle TEXT);
  CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT, body TEXT, topic TEXT, hidden INTEGER DEFAULT 0, created_at TEXT);
  CREATE TABLE comments (id INTEGER PRIMARY KEY, post_id INTEGER, resident_id INTEGER, user_id INTEGER, body TEXT);
  INSERT INTO users VALUES (1, 'asker');
`);
const post = db.prepare(`INSERT INTO posts (id, user_id, title, body, topic, hidden, created_at) VALUES (?, 1, ?, 'body', 'ask', 0, datetime('now', ?))`);
const answer = db.prepare(`INSERT INTO comments (post_id, resident_id, body) VALUES (?, ?, 'a')`);

// 오래된 미답 질문 하나
post.run(1, 'old and unanswered', '-30 hours');
// 그 뒤로 답이 4개씩 붙은 최신 글 5개
for (let id = 2; id <= 6; id++) {
  post.run(id, `answered ${id}`, `-${7 - id} hours`);
  for (let r = 1; r <= 4; r++) answer.run(id, r);
}
// 답이 2개만 붙은 글 하나(아직 대상), 숨긴 글, 이틀 넘은 글, 예약 글은 제외
post.run(7, 'half answered', '-3 hours'); answer.run(7, 1); answer.run(7, 2);
post.run(8, 'hidden', '-1 hours'); db.exec(`UPDATE posts SET hidden = 1 WHERE id = 8`);
post.run(9, 'too old', '-3 days');
post.run(10, 'scheduled', '+2 hours');

const rows = db.prepare(PENDING_HUMAN_POSTS_SQL).all();
const ids = rows.map((r) => r.id);
assert.deepEqual(ids, [1, 7], `expected the unanswered ones only, oldest first — got ${JSON.stringify(rows)}`);
assert.equal(rows[0].answers, 0);
assert.equal(rows[1].answers, 2);
assert.equal(rows[0].human_handle, 'asker');
console.log('PASS: watcher picks unanswered human posts before answered ones');

// 미답 글이 6개 넘으면 답 적은 것 → 오래된 것 순으로 5개
db.exec(`DELETE FROM posts; DELETE FROM comments`);
for (let id = 11; id <= 17; id++) post.run(id, `q${id}`, `-${20 - id} hours`);
answer.run(11, 1);
const many = db.prepare(PENDING_HUMAN_POSTS_SQL).all().map((r) => r.id);
assert.equal(many.length, 5);
assert.ok(!many.includes(11), 'the one with an answer yields to the ones with none');
assert.deepEqual(many, [12, 13, 14, 15, 16], `oldest first — got ${many}`);
console.log('PASS: watcher orders by fewest answers, then oldest');
