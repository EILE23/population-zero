// 순찰 1회의 운영 기록을 run-log.jsonl 에 한 줄 덧붙인다.
//
// CI 러너와 patrol/logs/ 는 작업이 끝나면 사라지고, Actions 실행 로그도 90일이면 없어진다.
// 비용·거부·모델 같은 값은 나중에 임계값을 조정할 근거라서 저장소에 남겨야 의미가 있다.
// 한 줄 JSON 이라 `tail`·`jq`·grep 으로 바로 읽힌다. 하루 8회 × 1줄이면 1년에 3천 줄이다.
import { appendFileSync, existsSync, readFileSync } from 'node:fs';

const dir = new URL('./', import.meta.url);
const read = (name) => { try { return JSON.parse(readFileSync(new URL(name, dir), 'utf8')); } catch { return null; } };

const d1 = read('./logs/d1-summary.json');
const gw = read('./logs/anthropic-summary.json');
const applied = read('./apply-result.json');

const record = {
  at: new Date().toISOString(),
  run: process.env.GITHUB_RUN_ID ?? null,
  mode: process.env.PATROL_MODE ?? null,
  ok: process.env.PATROL_OK === 'true',
  posts: applied?.post_ids?.length ?? 0,
  d1: d1 ? { statements: d1.statements, refused: d1.refused, deletes: (d1.rowDeletes ?? 0) + (d1.reactionDeletes ?? 0) } : null,
  gateway: gw ? { requests: gw.requests, refused: gw.refused, errors: gw.errors, in: gw.tokens?.input ?? 0, out: gw.tokens?.output ?? 0, models: gw.models ?? [] } : null,
};

const file = new URL('./run-log.jsonl', dir);
if (!existsSync(file)) appendFileSync(file, '');
appendFileSync(file, JSON.stringify(record) + '\n');
console.error(`run-log: ${JSON.stringify(record)}`);
