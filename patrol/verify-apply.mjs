// 이번 순찰이 정말 D1 에 적재됐는지 **세션 밖에서** 확인한다.
//
// apply-result.json 은 세션의 작업 폴더에 있던 파일이라 영수증으로 삼기 약하다.
// 진짜 증거는 D1 의 patrol_applies 다: run_id 는 patrol-output.json 내용의 해시이고,
// completed_at 은 모든 문장이 실제로 들어간 뒤에만 찍힌다.
// 그래서 여기서는 넘겨받은 patrol-output.json 을 직접 해싱해 그 행을 조회한다.
// 세션이 apply-result.json 을 위조해도 이 검사는 통과하지 못한다.
//
// 사용: node verify-apply.mjs        (0 = 적재 확인됨, 1 = 확인 실패)
// 필요: CLOUDFLARE_API_TOKEN — 신뢰된 후처리 job 에서만 실행한다.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { rows } from './d1.mjs';

const outPath = new URL('./patrol-output.json', import.meta.url);
if (!existsSync(outPath)) { console.error('verify-apply: no patrol-output.json — 이번 순찰은 적재할 게 없었다'); process.exit(1); }

const raw = readFileSync(outPath, 'utf8');
const runId = createHash('sha256').update(raw).digest('hex').slice(0, 32);

// 적재할 문장이 하나도 없는 순찰(기억만 갱신)은 원장에 행을 남기지 않는다 — 그것도 정상이다.
let parsed;
try { parsed = JSON.parse(raw); } catch { console.error('verify-apply: patrol-output.json 이 JSON 이 아니다'); process.exit(1); }
const nothingToApply = ['posts', 'replies', 'likes', 'poll_votes', 'moderation', 'follows', 'unfollows', 'blog_updates']
  .every((k) => !Array.isArray(parsed?.[k]) || parsed[k].length === 0);
if (nothingToApply) { console.error(`verify-apply: 적재 대상이 없는 순찰 (run ${runId}) — 기억은 유지한다`); process.exit(0); }

const row = (await rows(`SELECT started_at, completed_at, statements FROM patrol_applies WHERE run_id = '${runId}'`))[0];
if (!row) { console.error(`verify-apply: 원장에 run ${runId} 가 없다 — 적재가 시작되지 않았다`); process.exit(1); }
if (!row.completed_at) { console.error(`verify-apply: run ${runId} 는 ${row.started_at} 에 시작만 되고 끝나지 않았다 — 일부만 반영됐을 수 있다`); process.exit(1); }
console.error(`verify-apply: run ${runId} 확인됨 — ${row.statements}개 문장, ${row.completed_at}`);
