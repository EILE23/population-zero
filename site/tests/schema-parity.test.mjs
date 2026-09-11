// schema.sql 이 코드가 실제로 쓰는 테이블·컬럼을 모두 담고 있는지 검사한다.
//
// 왜 필요한가: 지금까지 컬럼은 마이그레이션으로만 추가되고 정본 스키마에는 반영되지 않았다.
// 그러면 README 대로 `db:init` 만 해서 만든 새 개발 DB 는 앱이 런타임에 깨진다
// (실제로 comments.parent_id 가 그랬다). 빌드도 타입 검사도 이걸 잡지 못한다.
//
// 실행: node site/tests/schema-parity.test.mjs
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const schema = readFileSync(path.join(root, 'schema.sql'), 'utf8');

let fail = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${extra}`); if (!ok) fail++; };

// schema.sql 을 문장 단위로 끊어 테이블 → 컬럼 목록을 뽑는다.
// 파일 전체에 정규식을 돌리면 한 줄짜리 CREATE TABLE 이 다음 테이블의 본문까지 삼킨다.
const tables = new Map();
for (const stmt of schema.split(/;\s*(?:\r?\n|$)/)) {
  const head = stmt.match(/CREATE TABLE (?:IF NOT EXISTS )?(\w+)\s*\(/i);
  if (!head) continue;
  const body = stmt.slice(head.index + head[0].length);
  const cols = new Set();
  // 여러 줄 정의는 줄 단위로, 한 줄 정의는 쉼표 단위로 — 둘 다 훑고 합친다
  for (const piece of [...body.split('\n'), ...body.split(',')]) {
    const name = piece.trim().replace(/--.*$/, '').trim()
      .match(/^(\w+)\s+(TEXT|INTEGER|REAL|BLOB|NUMERIC)\b/i)?.[1];
    if (name) cols.add(name);
  }
  tables.set(head[1], cols);
}

check('schema.sql 에서 테이블을 읽었다', tables.size >= 15, ` (${tables.size}개)`);

// 코드가 의존하는 것 — 여기 적힌 건 실제 쿼리에서 쓰는 이름이다
const REQUIRED = {
  residents: ['id', 'handle', 'tier', 'bio', 'blog_title'],
  users: ['id', 'handle', 'email', 'password_hash', 'google_sub', 'is_admin', 'bio', 'blog_title', 'email_verified', 'notifs_seen_at', 'handle_picked', 'avatar_url'],
  auth_tokens: ['token', 'user_id', 'kind', 'expires_at'],
  sessions: ['token', 'user_id', 'expires_at'],
  posts: ['id', 'resident_id', 'user_id', 'kind', 'title', 'body', 'media_type', 'media_ref', 'og_image', 'view_count', 'resident_view_count', 'hidden', 'region', 'topic', 'series', 'pinned', 'edited_at', 'created_at'],
  comments: ['id', 'post_id', 'resident_id', 'user_id', 'visitor_name', 'parent_id', 'body', 'hidden', 'edited_at', 'created_at'],
  poll_options: ['id', 'post_id', 'label', 'votes'],
  poll_votes: ['user_id', 'post_id', 'option_id'],
  resident_poll_votes: ['resident_id', 'post_id', 'option_id'],
  likes: ['user_id', 'post_id', 'created_at'],
  resident_likes: ['resident_id', 'post_id', 'created_at'],
  follows: ['follower_type', 'follower_id', 'target_type', 'target_id'],
  follow_events: ['follower_type', 'follower_id', 'target_type', 'target_id', 'action', 'created_at'],
  reports: ['id', 'comment_id', 'status'],
  contact_messages: ['name', 'email', 'body'],
  stats_daily: ['day', 'human_views'],
  auth_attempts: ['ip', 'ts'],
  wake_log: ['id', 'ts'],
  api_budget: ['day', 'calls'],
  site_meta: ['key', 'value', 'updated_at'],
  comment_decisions: ['comment_id', 'decision', 'attempts', 'ts'],
  patrol_applies: ['run_id', 'started_at', 'statements'],
};

for (const [table, cols] of Object.entries(REQUIRED)) {
  const have = tables.get(table);
  if (!have) { check(`${table} 테이블이 schema.sql 에 있다`, false); continue; }
  const missing = cols.filter((c) => !have.has(c));
  check(`${table} 컬럼`, missing.length === 0, missing.length ? ` — 누락: ${missing.join(', ')}` : '');
}

// 재초기화가 깨끗하려면 만드는 테이블은 전부 DROP 목록에도 있어야 한다
const dropped = new Set([...schema.matchAll(/DROP TABLE IF EXISTS (\w+);/g)].map((m) => m[1]));
const notDropped = [...tables.keys()].filter((t) => !dropped.has(t));
check('모든 테이블이 DROP 목록에 있다', notDropped.length === 0, notDropped.length ? ` — 빠짐: ${notDropped.join(', ')}` : '');

// 마이그레이션이 추가한 컬럼은 정본에도 있어야 한다 (이번 사고의 원인)
const migDir = path.join(root, 'migrations');
for (const f of readdirSync(migDir).filter((f) => f.endsWith('.sql'))) {
  const sql = readFileSync(path.join(migDir, f), 'utf8');
  for (const m of sql.matchAll(/ALTER TABLE (\w+)\s+ADD COLUMN (\w+)/gi)) {
    const [, table, col] = m;
    check(`${f}: ${table}.${col} 이 정본에 반영됨`, tables.get(table)?.has(col) === true);
  }
}

console.log(fail ? `\n${fail} failed` : '\nall passed');
process.exit(fail ? 1 : 0);
