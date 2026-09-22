// 게임 큐 — build-game.yml 이 쓴다. D1 은 d1.mjs(CI 에선 wrangler + CLOUDFLARE_API_TOKEN).
//   node games-queue.mjs pick <out.json>      큐의 첫 요청을 building 으로 바꾸고 파일로 쓴다. 없으면 'none' 출력
//   node games-queue.mjs done <slug> [note]   live
//   node games-queue.mjs fail <slug> <note>   두 번째 실패면 failed, 아니면 다시 queued
import { writeFileSync } from 'node:fs';
import { d1, rows } from './d1.mjs';

const esc = (s) => String(s ?? '').replace(/'/g, "''");
const [cmd, a, ...rest] = process.argv.slice(2).filter((x) => x !== '--remote' && x !== '--local');

if (cmd === 'pick') {
  const r = (await rows(`SELECT g.id, g.slug, g.title, g.prompt, g.note, g.user_id, COALESCE(u.handle, r.handle) AS maker FROM games g LEFT JOIN users u ON u.id = g.user_id LEFT JOIN residents r ON r.id = g.resident_id WHERE g.status = 'queued' AND g.attempts < 2 ORDER BY (g.user_id IS NULL), g.id LIMIT 1`))[0];
  if (!r) { console.log('none'); process.exit(0); }
  await d1(`UPDATE games SET status = 'building', attempts = attempts + 1, note = NULL WHERE id = ${Number(r.id)}`);
  writeFileSync(a || 'game-request.json', JSON.stringify(r, null, 1));
  console.log(r.slug);
} else if (cmd === 'done') {
  // 빌드는 review 로 끝난다 — 만든 사람이 해 보고 승인해야 놀이터에 걸린다(/api/games/<slug>/review)
  await d1(`UPDATE games SET status = 'review', built_at = datetime('now'), note = ${rest[0] ? `'${esc(rest[0]).slice(0, 200)}'` : 'NULL'} WHERE slug = '${esc(a)}'`);
  console.log('review', a);
} else if (cmd === 'fail') {
  await d1(`UPDATE games SET status = CASE WHEN attempts >= 2 THEN 'failed' ELSE 'queued' END, note = '${esc(rest.join(' ') || 'build failed').slice(0, 200)}' WHERE slug = '${esc(a)}'`);
  console.log('failed', a);
} else { console.log('usage: pick <out.json> | done <slug> [note] | fail <slug> <note>'); process.exit(2); }
