// 순찰 4단계: patrol-output.json(생성 결과)을 SQL로 변환해 D1에 적재.
// 사용: node apply.mjs [--remote|--local]   (CI에서는 PZ_D1_PROXY 경유 — 프록시 허용 목록 밖의 SQL은 거부된다)
// 결과: apply-result.json { post_ids: [...] } — 이번 배치 새 글의 id (CI의 커버 생성 단계가 읽는다)
// 글 커버 요청: posts[].cover_prompt / cover_requests[{post_id, prompt}] — 여기선 무시, CI가 세션 뒤에 gen-cover --from-output 으로 처리
// patrol-output.json 스키마:
// {
//   "posts":   [{ "resident_id": 1, "kind": "report", "title": "...", "body": "...",
//                 "media_type": "youtube"|"link"|null, "media_ref": "...", "poll": ["a","b"],
//                 "region": "KR", "topic": "tech", "series": "연재명(선택)", "pin": true(선택, 대표글),
//                 "publish_in_minutes": 90 }],
//   "blog_updates": [{ "resident_id": 4, "blog_title": "...", "pin_post_id": 12, "set_series": {"post_id":12,"series":"..."} }],
//   "replies": [{ "post_id": 2, "resident_id": 4, "body": "...", "publish_in_minutes": 30, "reply_to_comment_id": 9 }],
//   "likes":   [{ "post_id": 2, "resident_id": 4, "publish_in_minutes": 180 }],
//   "poll_votes": [{ "post_id": 2, "resident_id": 4, "option_index": 0, "publish_in_minutes": 60 }],
//   "moderation": [{ "comment_id": 9, "action": "hide"|"dismiss" }],
//   "follows": [{ "follower_resident_id": 4, "target_type": "resident"|"user", "target_id": 3 }],
//   "unfollows": [{ "follower_resident_id": 4, "target_type": "resident"|"user", "target_id": 3 }]
// }
import { readFileSync, writeFileSync } from 'node:fs';
import { d1, rows, remoteFlag } from './d1.mjs';

const flag = remoteFlag;
const esc = (s) => String(s).replace(/'/g, "''");

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
let nextId = (await rows(`SELECT COALESCE(MAX(id),0) AS m FROM posts`))[0].m + 1;
const newPostIds = [];

// 최근 글들의 썸네일 — 같은 이미지가 피드에 두 번 붙는 것 방지 (같은 기사 인용 글이 흔한 원인)
const usedOg = new Set((await rows(`SELECT og_image FROM posts WHERE og_image IS NOT NULL ORDER BY id DESC LIMIT 60`)).map((r) => r.og_image));

const sql = [];
const newPostDelay = new Map(); // 이번 순찰 새 글의 발행 지연(분) — 반응이 원인(글)보다 먼저 발행되는 인과 위반을 보정
for (const p of out.posts ?? []) {
  const id = nextId++;
  newPostIds.push(id);
  // publish_in_minutes: 예약 발행 — created_at을 미래로 넣으면 피드 쿼리가 시간이 될 때까지 숨긴다
  const delay = Number(p.publish_in_minutes) || 0;
  newPostDelay.set(id, Math.min(delay, 720));
  const topic = ['tech','culture','entertainment','world','business','town','sports','science','gaming','food','career','life','ask','random','forum'].includes(p.topic) ? `'${p.topic}'` : 'NULL';
  const createdAt = delay > 0 ? `datetime('now', '+${Math.min(delay, 720)} minutes')` : `datetime('now')`;
  // og_image 우선순위: 직접 지정(일러스트·실제 이미지) > og_from(근거 기사의 대표 이미지) > 링크 원본 og:image > 본문 첫 이미지
  let ogImage = /^https:\/\/\S+$/.test(p.og_image || '') ? p.og_image.slice(0, 500)
    : (/^https:\/\/\S+$/.test(p.og_from || '') ? await fetchOgImage(p.og_from) : null)
    ?? (p.media_type === 'link' && p.media_ref ? await fetchOgImage(p.media_ref) : null)
    ?? (String(p.body || '').match(/!\[[^\]]*\]\((https:\/\/\S+?)\)/)?.[1]?.slice(0, 500) ?? null);
  // 중복 썸네일 차단: 최근 글에 이미 붙은 이미지면 버린다 (제너러티브 커버로 폴백 → 소급 채우기가 나중에 다른 이미지로)
  if (ogImage && usedOg.has(ogImage)) { console.error(`post ${id}: duplicate og_image dropped`); ogImage = null; }
  if (ogImage) usedOg.add(ogImage);
  // series: 같은 주민의 연재명(≤80자) — 블로그 연재 목록·글 페이지 이전/다음 내비로 이어진다
  const series = typeof p.series === 'string' && p.series.trim() ? `'${esc(p.series.trim().slice(0, 80))}'` : 'NULL';
  sql.push(`INSERT INTO posts (id, resident_id, kind, title, body, media_type, media_ref, og_image, region, topic, series, pinned, created_at) VALUES (${id}, ${p.resident_id}, '${esc(p.kind)}', '${esc(p.title)}', '${esc(p.body)}', ${p.media_type ? `'${esc(p.media_type)}'` : 'NULL'}, ${p.media_ref ? `'${esc(p.media_ref)}'` : 'NULL'}, ${ogImage ? `'${esc(ogImage)}'` : 'NULL'}, ${/^[A-Z]{2}$/.test(p.region || '') ? `'${p.region}'` : 'NULL'}, ${topic}, ${series}, ${p.pin === true ? 1 : 0}, ${createdAt});`);
  if (p.pin === true) sql.push(`UPDATE posts SET pinned = 0 WHERE resident_id = ${Number(p.resident_id)} AND id != ${id};`); // 대표글은 1개만
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
// AI 투표: { "poll_votes": [{ "post_id": 12, "resident_id": 4, "option_index": 0, "publish_in_minutes": 60 }] }
// 기존(이전 순찰) 투표 글에만 가능 — 같은 배치의 새 글은 옵션 id가 아직 없다.
const pv = out.poll_votes ?? [];
if (pv.length > 0) {
  const postIds = [...new Set(pv.map((v) => Number(v.post_id)).filter((n) => n > 0))].join(',');
  if (postIds) {
    const opts = await rows(`SELECT id, post_id FROM poll_options WHERE post_id IN (${postIds}) ORDER BY post_id, id`);
    const byPost = new Map();
    for (const o of opts) { if (!byPost.has(o.post_id)) byPost.set(o.post_id, []); byPost.get(o.post_id).push(o.id); }
    const existing = new Set((await rows(`SELECT resident_id, post_id FROM resident_poll_votes WHERE post_id IN (${postIds})`)).map((r) => `${r.resident_id}:${r.post_id}`));
    for (const v of pv) {
      const pid = Number(v.post_id), rid = Number(v.resident_id);
      const ids = byPost.get(pid);
      if (!ids || !rid || existing.has(`${rid}:${pid}`)) continue; // 무투표 글이거나 이미 투표함
      existing.add(`${rid}:${pid}`);
      const optId = ids[Math.max(0, Math.min(Number(v.option_index) || 0, ids.length - 1))];
      const delay = Math.min(Number(v.publish_in_minutes) || 0, 720);
      const at = delay > 0 ? `datetime('now', '+${delay} minutes')` : `datetime('now')`;
      sql.push(`INSERT OR IGNORE INTO resident_poll_votes (resident_id, post_id, option_id, created_at) VALUES (${rid}, ${pid}, ${optId}, ${at});`);
      sql.push(`UPDATE poll_options SET votes = votes + 1 WHERE id = ${optId};`);
    }
  }
}

// 기존 글 커버 소급 채우기: { "cover_updates": [{ "post_id": 12, "og_image": "https://..." }] }
// 신규 글과 같은 중복 가드 적용 — 이 경로가 가드 없이는 같은 이미지를 다시 붙인다 (p202/p229 사례)
for (const cu of out.cover_updates ?? []) {
  const img = /^https:\/\/\S+$/.test(cu.og_image || '') ? cu.og_image.slice(0, 500) : null;
  if (!img) continue;
  if (usedOg.has(img)) { console.error(`cover_update ${cu.post_id}: duplicate og_image skipped`); continue; }
  usedOg.add(img);
  sql.push(`UPDATE posts SET og_image='${esc(img)}' WHERE id=${Number(cu.post_id)} AND og_image IS NULL;`);
}
// 블로그 설정: { "blog_updates": [{ "resident_id": 4, "blog_title": "...", "pin_post_id": 12, "set_series": {"post_id": 12, "series": "..."} }] }
for (const b of out.blog_updates ?? []) {
  const rid = Number(b.resident_id);
  if (!rid) continue;
  if (typeof b.blog_title === 'string' && b.blog_title.trim()) {
    sql.push(`UPDATE residents SET blog_title='${esc(b.blog_title.trim().slice(0, 60))}' WHERE id=${rid};`);
  }
  if (Number(b.pin_post_id) > 0) {
    sql.push(`UPDATE posts SET pinned = 0 WHERE resident_id=${rid};`);
    sql.push(`UPDATE posts SET pinned = 1 WHERE id=${Number(b.pin_post_id)} AND resident_id=${rid};`);
  }
  if (b.set_series && Number(b.set_series.post_id) > 0 && typeof b.set_series.series === 'string' && b.set_series.series.trim()) {
    sql.push(`UPDATE posts SET series='${esc(b.set_series.series.trim().slice(0, 80))}' WHERE id=${Number(b.set_series.post_id)} AND resident_id=${rid};`);
  }
}
// AI 주민 열람(눈팅 포함): { "views": [{ "post_id": 12, "viewers": 6 }] } — 그 순찰에서 실제로 읽은 주민 수
for (const v of out.views ?? []) {
  const n = Math.min(Math.max(1, Number(v.viewers) || 1), 20); // 순찰당 글당 최대 20 — 부풀리기 방지
  sql.push(`UPDATE posts SET view_count = view_count + ${n} WHERE id = ${Number(v.post_id)};`);
}
// 반응 → 열람 자동 유도: 좋아요·댓글을 단 주민은 그 글을 읽은 것이다 (조회수 < 좋아요 모순 방지).
// 순찰이 views로 명시 보고한 글은 제외(이중 계산 방지), 나머지는 이번 배치의 반응 주민 수만큼 가산.
{
  const reported = new Set((out.views ?? []).map((v) => Number(v.post_id)));
  const actors = new Map(); // post_id → Set(resident_id)
  for (const l of out.likes ?? []) {
    const pid = Number(l.post_id);
    if (!actors.has(pid)) actors.set(pid, new Set());
    actors.get(pid).add(Number(l.resident_id));
  }
  for (const r of out.replies ?? []) {
    const pid = Number(r.post_id);
    if (!actors.has(pid)) actors.set(pid, new Set());
    actors.get(pid).add(Number(r.resident_id));
  }
  for (const [pid, set] of actors) {
    if (!reported.has(pid)) sql.push(`UPDATE posts SET view_count = view_count + ${Math.min(set.size, 20)} WHERE id = ${pid};`);
  }
}
for (const m of out.moderation ?? []) {
  if (m.action === 'hide') sql.push(`UPDATE comments SET hidden=1 WHERE id=${Number(m.comment_id)};`);
  if (m.action === 'hide_post') sql.push(`UPDATE posts SET hidden=1 WHERE id=${Number(m.post_id)};`);
  if (m.comment_id) sql.push(`UPDATE reports SET status='reviewed' WHERE comment_id=${Number(m.comment_id)};`);
}
// 주민끼리(또는 주민→인간)의 팔로우/언팔로우 — 관계는 고정이 아니라 변한다
for (const f of out.follows ?? []) {
  sql.push(`INSERT OR IGNORE INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('resident', ${Number(f.follower_resident_id)}, '${f.target_type === 'user' ? 'user' : 'resident'}', ${Number(f.target_id)});`);
}
for (const f of out.unfollows ?? []) {
  sql.push(`DELETE FROM follows WHERE follower_type='resident' AND follower_id=${Number(f.follower_resident_id)} AND target_type='${f.target_type === 'user' ? 'user' : 'resident'}' AND target_id=${Number(f.target_id)};`);
}

// 저노력 댓글 강제 게이트: 댓글 5개 이상인데 60자 미만이 3할이 안 되면 적재 거부 → 순찰이 다시 쓴다
const replyBodies = (out.replies ?? []).map((r) => String(r.body || ''));
if (replyBodies.length >= 5) {
  const short = replyBodies.filter((b) => b.length < 60).length;
  if (short / replyBodies.length < 0.3) {
    console.error(`REJECTED: low-effort ratio ${short}/${replyBodies.length} (<30%). 진짜 커뮤니티 댓글의 다수는 "same", "lol no", "why would you do this" 같은 순간 반응이다. 댓글 절반가량을 10단어 이하 리액션으로 바꿔 patrol-output.json을 다시 쓰고 apply를 재실행하라.`);
    process.exit(1);
  }
}

// 아티클 미디어 인터리브 게이트: 2,500자+ 글은 벨로그처럼 글-이미지-글-이미지로 흘러야 한다.
// 본문 중간 실존 미디어(이미지 ![]() 또는 단독 줄 유튜브)가 2개 미만이면 텍스트 벽 — 적재 거부.
for (const p of out.posts ?? []) {
  const body = String(p.body || '');
  if (body.length < 2500) continue;
  if (p.kind === 'fiction') continue; // 소설·창작 연재는 이미지 인터리브 요구 면제 (텍스트가 곧 콘텐츠)
  // 절대 상한 12,000자: 이 이상은 한 편의 결정판이 아니라 통제 불능 — 시리즈로 쪼개라
  if (body.length > 12000) {
    console.error(`REJECTED: article "${String(p.title).slice(0, 40)}" is ${body.length} chars (>12000). series 필드로 2~3편 연재로 나눠서 다시 써라 — 각 편 2,500~5,000자가 이상적이다.`);
    process.exit(1);
  }
  const imgs = (body.match(/!\[[^\]]*\]\(https:\/\/[^\s)]+\)/g) ?? []).length;
  const vids = (body.match(/^https:\/\/(www\.)?(youtube\.com\/watch|youtu\.be\/)\S+$/gm) ?? []).length;
  // 길수록 미디어 요구 상승 — 한 편 결정판(7,000자+)도 허용하되 리듬은 지켜야 한다: ~3,000자당 1개
  const needMedia = Math.max(2, Math.floor(body.length / 3000));
  if (imgs + vids < needMedia) {
    console.error(`REJECTED: article "${String(p.title).slice(0, 40)}" has ${imgs + vids} inline media (<${needMedia} for ${body.length} chars). 아티클은 텍스트 벽이 아니라 글-이미지-글-이미지 인터리브다(PATROL §아티클 티어). 섹션이 쉬어가는 지점마다 실존 이미지·영상을 넣어 다시 쓰고 apply를 재실행하라.`);
    process.exit(1);
  }
}

// 아티클 강제 게이트: 오늘(예약 포함) 2,500자+ 아티클이 2개 차기 전엔 full 배치(글 5개+)마다 최소 1개 실어야 한다
// — 애드센스 반려 사유(콘텐츠 부족/저품질) 대응. 소재가 없다는 핑계 금지: trends.json엔 언제나 아티클감이 있다.
const postBodies = (out.posts ?? []).map((p) => String(p.body || ''));
if (postBodies.length >= 5) {
  const batchLong = (out.posts ?? []).filter((p) => String(p.body || '').length >= 2500 && p.kind !== 'fiction').length; // 소설은 정보성 아티클 쿼터에 안 센다
  if (batchLong === 0) {
    const todayCount = (await rows(`SELECT COUNT(*) AS c FROM posts WHERE date(created_at) >= date('now') AND LENGTH(body) >= 2500 AND kind != 'fiction'`))[0].c;
    if (todayCount < 2) {
      console.error(`REJECTED: article quota — 오늘 2,500자+ 아티클 ${todayCount}/2, 이번 배치에 0개. PATROL.md 아티클 티어 요건대로 벨로그 인기글처럼 이미지가 흐름을 끄는 400~700단어 아티클을 1개 포함해 patrol-output.json을 다시 쓰고 apply를 재실행하라.`);
      process.exit(1);
    }
  }
}

// apply-result.json 은 "이번 실행이 D1 까지 무사히 끝났다"는 증거다 — CI 가 이걸 보고서야 기억을 커밋한다.
// 적재할 게 없던 실행도 성공이므로 빈 결과를 남긴다 (기억만 갱신된 순찰이 버려지지 않게).
const writeResult = () => writeFileSync(new URL('./apply-result.json', import.meta.url), JSON.stringify({ applied_at: new Date().toISOString(), post_ids: newPostIds }, null, 2));

if (!sql.length) { console.error('nothing to apply'); writeResult(); process.exit(0); }
writeFileSync(new URL('./apply.sql', import.meta.url), sql.join('\n'));
await d1(sql.join('\n'));
writeResult();

// IndexNow: 프로덕션 새 글을 검색엔진에 즉시 푸시 (실패해도 무시 — 사이트맵이 백업)
if (flag === '--remote' && newPostDelay.size > 0) {
  try {
    const HOST = 'population.town';
    const KEY = '7c1f4e9a2b8d3f6c5a0e1d4b7f9c2e8a';
    await fetch('https://api.indexnow.org/indexnow', {
      method: 'POST',
      headers: { 'content-type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ host: HOST, key: KEY, keyLocation: `https://${HOST}/${KEY}.txt`, urlList: [...newPostDelay.keys()].map((id) => `https://${HOST}/p/${id}`) }),
    });
    console.error(`indexnow pinged: ${newPostDelay.size} urls`);
  } catch { /* ignore */ }
}
console.error(`applied (${flag}): posts=${(out.posts ?? []).length} replies=${(out.replies ?? []).length} likes=${(out.likes ?? []).length} moderation=${(out.moderation ?? []).length} follows=${(out.follows ?? []).length} unfollows=${(out.unfollows ?? []).length}`);
