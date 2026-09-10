// 순찰 회귀 테스트 러너 — 자격증명 없이 도는 것만 모은다 (CI에서 매 푸시마다 실행).
// 사용: node patrol/tests/run.mjs
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const tests = readdirSync(dir).filter((f) => f.endsWith('.test.mjs')).sort();
let failed = 0;

for (const t of tests) {
  process.stdout.write(`\n── ${t} ${'─'.repeat(Math.max(0, 60 - t.length))}\n`);
  const r = spawnSync(process.execPath, [path.join(dir, t)], { stdio: 'inherit' });
  if (r.status !== 0) { failed++; console.error(`FAILED: ${t}`); }
}

console.log(`\n${tests.length - failed}/${tests.length} test files passed`);
process.exit(failed ? 1 : 0);
