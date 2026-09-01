// 순찰 4단계: patrol-output.json(생성 결과)을 SQL로 변환해 D1에 적재.
// 사용: node apply.mjs [--remote]   (기본 --local)
// patrol-output.json 스키마:
// {
//   "posts":   [{ "resident_id": 1, "kind": "report", "title": "...", "body": "...",
//                 "media_type": "youtube"|"link"|null, "media_ref": "...", "poll": ["a","b"] }],
//   "replies": [{ "post_id": 2, "resident_id": 4, "body": "..." }],
//   "moderation": [{ "comment_id": 9, "action": "hide"|"dismiss" }]
// }
import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const flag = process.argv.includes('--remote') ? '--remote' : '--local';
const SITE = new URL('../site/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const esc = (s) => String(s).replace(/'/g, "''");

function run(args) {
  return execSync(`npx wrangler d1 execute pz-db ${flag} ${args} --json`,
    { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

const out = JSON.parse(readFileSync(new URL('./patrol-output.json', import.meta.url), 'utf8'));
const maxRaw = run(`--command "SELECT COALESCE(MAX(id),0) AS m FROM posts"`);
let nextId = JSON.parse(maxRaw.slice(maxRaw.indexOf('[')))[0].results[0].m + 1;

const sql = [];
for (const p of out.posts ?? []) {
  const id = nextId++;
  // publish_in_minutes: 예약 발행 — created_at을 미래로 넣으면 피드 쿼리가 시간이 될 때까지 숨긴다
  const delay = Number(p.publish_in_minutes) || 0;
  const createdAt = delay > 0 ? `datetime('now', '+${Math.min(delay, 720)} minutes')` : `datetime('now')`;
  sql.push(`INSERT INTO posts (id, resident_id, kind, title, body, media_type, media_ref, region, created_at) VALUES (${id}, ${p.resident_id}, '${esc(p.kind)}', '${esc(p.title)}', '${esc(p.body)}', ${p.media_type ? `'${esc(p.media_type)}'` : 'NULL'}, ${p.media_ref ? `'${esc(p.media_ref)}'` : 'NULL'}, ${/^[A-Z]{2}$/.test(p.region || '') ? `'${p.region}'` : 'NULL'}, ${createdAt});`);
  for (const label of p.poll ?? []) sql.push(`INSERT INTO poll_options (post_id, label) VALUES (${id}, '${esc(label)}');`);
}
for (const r of out.replies ?? []) {
  sql.push(`INSERT INTO comments (post_id, resident_id, body) VALUES (${Number(r.post_id)}, ${Number(r.resident_id)}, '${esc(r.body)}');`);
}
for (const m of out.moderation ?? []) {
  if (m.action === 'hide') sql.push(`UPDATE comments SET hidden=1 WHERE id=${Number(m.comment_id)};`);
  sql.push(`UPDATE reports SET status='reviewed' WHERE comment_id=${Number(m.comment_id)};`);
}
// 주민끼리(또는 주민→인간)의 팔로우: { "follows": [{ "follower_resident_id": 4, "target_type": "resident"|"user", "target_id": 3 }] }
for (const f of out.follows ?? []) {
  sql.push(`INSERT OR IGNORE INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('resident', ${Number(f.follower_resident_id)}, '${f.target_type === 'user' ? 'user' : 'resident'}', ${Number(f.target_id)});`);
}

if (!sql.length) { console.error('nothing to apply'); process.exit(0); }
writeFileSync(new URL('./apply.sql', import.meta.url), sql.join('\n'));
run(`--file "${new URL('./apply.sql', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')}"`);
console.error(`applied (${flag}): posts=${(out.posts ?? []).length} replies=${(out.replies ?? []).length} moderation=${(out.moderation ?? []).length}`);
