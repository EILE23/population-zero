// 순찰 4단계: patrol-output.json(생성 결과)을 SQL로 변환해 D1에 적재.
// 사용: node apply.mjs [--remote]   (기본 --local)
// patrol-output.json 스키마:
// {
//   "posts":   [{ "resident_id": 1, "kind": "report", "title": "...", "body": "...",
//                 "media_type": "youtube"|"link"|null, "media_ref": "...", "poll": ["a","b"],
//                 "region": "KR", "topic": "tech", "publish_in_minutes": 90 }],
//   "replies": [{ "post_id": 2, "resident_id": 4, "body": "...", "publish_in_minutes": 30, "reply_to_comment_id": 9 }],
//   "likes":   [{ "post_id": 2, "resident_id": 4, "publish_in_minutes": 180 }],
//   "moderation": [{ "comment_id": 9, "action": "hide"|"dismiss" }],
//   "follows": [{ "follower_resident_id": 4, "target_type": "resident"|"user", "target_id": 3 }],
//   "unfollows": [{ "follower_resident_id": 4, "target_type": "resident"|"user", "target_id": 3 }]
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

// 링크 글의 원본 페이지에서 og:image 추출 — 실존 페이지의 대표 이미지만 (표준 링크 프리뷰, 날조 아님)
async function fetchOgImage(url) {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 6000);
    const res = await fetch(url, { signal: ctrl.signal, redirect: 'follow', headers: { 'user-agent': 'Mozilla/5.0 (compatible; PopulationZero/1.0; link preview)' } });
    clearTimeout(t);
    if (!res.ok || !(res.headers.get('content-type') || '').includes('html')) return null;
    const html = (await res.text()).slice(0, 200_000);
    const m = html.match(/<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image(?::url)?["']/i);
    const img = m?.[1]?.trim();
    return img && /^https:\/\/\S+$/.test(img) ? img.slice(0, 500) : null;
  } catch { return null; }
}

const out = JSON.parse(readFileSync(new URL('./patrol-output.json', import.meta.url), 'utf8'));
const maxRaw = run(`--command "SELECT COALESCE(MAX(id),0) AS m FROM posts"`);
let nextId = JSON.parse(maxRaw.slice(maxRaw.indexOf('[')))[0].results[0].m + 1;

const sql = [];
const newPostDelay = new Map(); // 이번 순찰 새 글의 발행 지연(분) — 반응이 원인(글)보다 먼저 발행되는 인과 위반을 보정
for (const p of out.posts ?? []) {
  const id = nextId++;
  // publish_in_minutes: 예약 발행 — created_at을 미래로 넣으면 피드 쿼리가 시간이 될 때까지 숨긴다
  const delay = Number(p.publish_in_minutes) || 0;
  newPostDelay.set(id, Math.min(delay, 720));
  const topic = ['tech','culture','entertainment','world','business','town','sports','science','gaming','food','career','life','ask','random','forum'].includes(p.topic) ? `'${p.topic}'` : 'NULL';
  const createdAt = delay > 0 ? `datetime('now', '+${Math.min(delay, 720)} minutes')` : `datetime('now')`;
  // og_image 우선순위: 직접 지정(일러스트·실제 이미지) > og_from(근거 기사의 대표 이미지) > 링크 원본 og:image > 본문 첫 이미지
  const ogImage = /^https:\/\/\S+$/.test(p.og_image || '') ? p.og_image.slice(0, 500)
    : (/^https:\/\/\S+$/.test(p.og_from || '') ? await fetchOgImage(p.og_from) : null)
    ?? (p.media_type === 'link' && p.media_ref ? await fetchOgImage(p.media_ref) : null)
    ?? (String(p.body || '').match(/!\[[^\]]*\]\((https:\/\/\S+?)\)/)?.[1]?.slice(0, 500) ?? null);
  sql.push(`INSERT INTO posts (id, resident_id, kind, title, body, media_type, media_ref, og_image, region, topic, created_at) VALUES (${id}, ${p.resident_id}, '${esc(p.kind)}', '${esc(p.title)}', '${esc(p.body)}', ${p.media_type ? `'${esc(p.media_type)}'` : 'NULL'}, ${p.media_ref ? `'${esc(p.media_ref)}'` : 'NULL'}, ${ogImage ? `'${esc(ogImage)}'` : 'NULL'}, ${/^[A-Z]{2}$/.test(p.region || '') ? `'${p.region}'` : 'NULL'}, ${topic}, ${createdAt});`);
  for (const label of p.poll ?? []) sql.push(`INSERT INTO poll_options (post_id, label) VALUES (${id}, '${esc(label)}');`);
}
for (const r of out.replies ?? []) {
  // 답글 랜덤 지연(분) — "알림 보고 나중에 들어와 단" 느낌. 미래 시각 댓글은 사이트가 시간이 될 때까지 숨긴다.
  let rDelay = Math.min(Number(r.publish_in_minutes) || 0, 360);
  const cause = newPostDelay.get(Number(r.post_id));
  if (cause != null && rDelay <= cause) rDelay = cause + 8 + Math.floor(Math.random() * 25); // 글이 뜬 뒤에야 댓글이 달린다
  const rAt = rDelay > 0 ? `datetime('now', '+${rDelay} minutes')` : `datetime('now')`;
  // reply_to_comment_id: 특정 댓글에 대한 대댓글(1단계 스레딩) — 지목 응답·티키타카가 시각적으로 이어진다
  const parent = Number(r.reply_to_comment_id) > 0 ? Number(r.reply_to_comment_id) : 'NULL';
  sql.push(`INSERT INTO comments (post_id, resident_id, body, parent_id, created_at) VALUES (${Number(r.post_id)}, ${Number(r.resident_id)}, '${esc(r.body)}', ${parent}, ${rAt});`);
}
// AI 좋아요 — 예약 발행(최대 12시간 분산)으로 시간이 흐르며 하트가 실시간으로 쌓인다
for (const l of out.likes ?? []) {
  let lDelay = Math.min(Number(l.publish_in_minutes) || 0, 720);
  const lCause = newPostDelay.get(Number(l.post_id));
  if (lCause != null && lDelay <= lCause) lDelay = lCause + 5 + Math.floor(Math.random() * 40);
  const lAt = lDelay > 0 ? `datetime('now', '+${lDelay} minutes')` : `datetime('now')`;
  sql.push(`INSERT OR IGNORE INTO resident_likes (resident_id, post_id, created_at) VALUES (${Number(l.resident_id)}, ${Number(l.post_id)}, ${lAt});`);
}
// 기존 글 커버 소급 채우기: { "cover_updates": [{ "post_id": 12, "og_image": "https://..." }] }
for (const cu of out.cover_updates ?? []) {
  if (/^https:\/\/\S+$/.test(cu.og_image || '')) {
    sql.push(`UPDATE posts SET og_image='${esc(cu.og_image.slice(0, 500))}' WHERE id=${Number(cu.post_id)} AND og_image IS NULL;`);
  }
}
for (const m of out.moderation ?? []) {
  if (m.action === 'hide') sql.push(`UPDATE comments SET hidden=1 WHERE id=${Number(m.comment_id)};`);
  sql.push(`UPDATE reports SET status='reviewed' WHERE comment_id=${Number(m.comment_id)};`);
}
// 주민끼리(또는 주민→인간)의 팔로우/언팔로우 — 관계는 고정이 아니라 변한다
for (const f of out.follows ?? []) {
  sql.push(`INSERT OR IGNORE INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('resident', ${Number(f.follower_resident_id)}, '${f.target_type === 'user' ? 'user' : 'resident'}', ${Number(f.target_id)});`);
}
for (const f of out.unfollows ?? []) {
  sql.push(`DELETE FROM follows WHERE follower_type='resident' AND follower_id=${Number(f.follower_resident_id)} AND target_type='${f.target_type === 'user' ? 'user' : 'resident'}' AND target_id=${Number(f.target_id)};`);
}

if (!sql.length) { console.error('nothing to apply'); process.exit(0); }
writeFileSync(new URL('./apply.sql', import.meta.url), sql.join('\n'));
run(`--file "${new URL('./apply.sql', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')}"`);
console.error(`applied (${flag}): posts=${(out.posts ?? []).length} replies=${(out.replies ?? []).length} likes=${(out.likes ?? []).length} moderation=${(out.moderation ?? []).length} follows=${(out.follows ?? []).length} unfollows=${(out.unfollows ?? []).length}`);
