// apply.mjs 스모크 — 실제 apply 본문을 **실제 d1-proxy** 에 붙여 "적재할 게 있는 표준 경로" 를 끝까지 돈다.
// 이 경로가 없어서 미정의 runId(F01)가 세 번의 리뷰를 지나도록 남았다.
// 원장(patrol_applies)은 프록시의 /apply 만 쓴다 — 가짜 D1 이 PRIMARY KEY 처럼 군다.
//   1) 첫 적용: 원장 INSERT(내용 해시) → 문장 적재 → 완료 표시 → apply-result.json
//   2) 같은 파일 재적용: 원장 충돌 → REFUSED(이미 적재), 적재 0
//   3) 끝나지 않은 이전 실행: completed_at 없는 행 → REFUSED (사람 확인 요구)
//   4) 세션이 SQL 로 원장을 만지려 하면 프록시가 거부한다
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const dir = mkdtempSync(path.join(tmpdir(), 'pz-apply-'));
const output = { replies: [{ post_id: 5, resident_id: 13, body: 'objection noted. overruled.', publish_in_minutes: 0 }] };
const raw = JSON.stringify(output, null, 2);
writeFileSync(path.join(dir, 'patrol-output.json'), raw);
const expectedRun = createHash('sha256').update(raw).digest('hex').slice(0, 32);

// 가짜 D1(업스트림) — 프록시가 보내는 SQL 을 종류별로 답한다. 원장은 실제 PRIMARY KEY 처럼 군다.
const ledger = new Map(); // run_id → { statements, started_at, completed_at }
const received = [];
const fake = createServer(async (req, res) => {
  let body = ''; for await (const c of req) body += c;
  const { sql } = JSON.parse(body);
  received.push(sql);
  const reply = (results = [{ ok: 1 }]) => { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ success: true, result: [{ results, meta: {} }] })); };
  const refuse = (msg) => { res.writeHead(400, { 'content-type': 'application/json' }); res.end(JSON.stringify({ success: false, errors: [{ message: msg }] })); };
  if (/COALESCE\(MAX\(id\),0\)/.test(sql)) return reply([{ m: 100 }]);
  if (/SELECT og_image FROM posts/.test(sql)) return reply([]);
  if (/SELECT COUNT\(\*\) AS c FROM posts/.test(sql)) return reply([{ c: 5 }]);
  if (/SELECT id FROM posts WHERE id IN/.test(sql) || /SELECT id FROM comments WHERE id IN/.test(sql)) return reply([]);
  const ins = sql.match(/INSERT INTO patrol_applies \(run_id, statements\) VALUES \('([0-9a-f]+)', (\d+)\)/);
  if (ins) {
    if (ledger.has(ins[1])) return refuse('UNIQUE constraint failed: patrol_applies.run_id');
    ledger.set(ins[1], { statements: Number(ins[2]), started_at: '2026-09-14 00:00:00', completed_at: null });
    return reply();
  }
  const sel = sql.match(/FROM patrol_applies WHERE run_id = '([0-9a-f]+)'/);
  if (sel) { const r = ledger.get(sel[1]); return reply(r ? [r] : []); }
  const done = sql.match(/UPDATE patrol_applies SET completed_at = datetime\('now'\) WHERE run_id = '([0-9a-f]+)'/);
  if (done) { const r = ledger.get(done[1]); if (r) r.completed_at = '2026-09-14 00:00:05'; return reply(); }
  return reply(); // 적재 문장들
});
fake.listen(0, '127.0.0.1');
await once(fake, 'listening');

// 실제 프록시 — 토큰은 stdin, 업스트림은 위 가짜 D1
const PORT = 8796;
const proxy = spawn(process.execPath, [fileURLToPath(new URL('../d1-proxy.mjs', import.meta.url))], {
  env: { ...process.env, PZ_D1_PROXY_PORT: String(PORT), PZ_D1_UPSTREAM: `http://127.0.0.1:${fake.address().port}/` },
  stdio: ['pipe', 'ignore', 'pipe'],
});
let plog = ''; proxy.stderr.on('data', (d) => { plog += d; });
proxy.stdin.end('test-token\n');
for (let i = 0; i < 50 && !plog.includes('listening on'); i++) await new Promise((r) => setTimeout(r, 100));
const PROXY = `http://127.0.0.1:${PORT}`;

async function runApply() {
  received.length = 0;
  const p = spawn(process.execPath, [fileURLToPath(new URL('../apply.mjs', import.meta.url)), '--remote'], {
    env: { ...process.env, PZ_D1_PROXY: PROXY, PZ_APPLY_DIR: dir },
    cwd: fileURLToPath(new URL('../', import.meta.url)),
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let err = ''; p.stderr.on('data', (d) => { err += d; });
  const [code] = await once(p, 'close');
  return { code, err };
}

let pass = 0, fail = 0;
const check = (name, ok, detail = '') => { ok ? pass++ : fail++; console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${ok ? '' : ` — ${detail}`}`); };

try {
  check('프록시가 떴다', plog.includes('listening on'), plog.slice(-300));

  // 1) 첫 적용
  const first = await runApply();
  check('첫 적용은 성공한다', first.code === 0, first.err.slice(-600) + plog.slice(-300));
  check('원장에 내용 해시가 실린다', ledger.has(expectedRun), [...ledger.keys()].join(','));
  check('적재 뒤 완료 표시가 찍힌다', ledger.get(expectedRun)?.completed_at != null);
  const ledgerAt = received.findIndex((s) => /INSERT INTO patrol_applies/.test(s));
  const commentAt = received.findIndex((s) => /INSERT INTO comments/.test(s));
  check('원장 기록이 적재보다 먼저다', ledgerAt > -1 && commentAt > -1 && ledgerAt < commentAt, `${ledgerAt} vs ${commentAt}`);
  check('apply-result.json 이 남는다', existsSync(path.join(dir, 'apply-result.json')));
  check('runId 미정의 같은 실행 오류가 없다', !/ReferenceError/.test(first.err), first.err.slice(0, 300));

  // 2) 같은 파일 재적용
  rmSync(path.join(dir, 'apply-result.json'), { force: true });
  const again = await runApply();
  check('같은 출력의 재적용은 거부된다', again.code === 1 && /이미 적재됐다/.test(again.err), `${again.code} ${again.err.slice(-300)}`);
  check('재적용에서 문장이 하나도 안 나간다', !received.some((s) => /INSERT INTO comments/.test(s)));
  check('거부된 실행은 결과 파일을 남기지 않는다', !existsSync(path.join(dir, 'apply-result.json')));

  // 3) 끝나지 않은 이전 실행
  ledger.get(expectedRun).completed_at = null;
  const half = await runApply();
  check('미완 실행이 남아 있으면 거부하고 사람 확인을 요구한다', half.code === 1 && /끝나지 않은 채/.test(half.err), half.err.slice(-300));

  // 4) 세션이 원장을 직접 만지는 길은 없다
  const forged = await fetch(`${PROXY}/query`, { method: 'POST', body: JSON.stringify({ sql: `UPDATE patrol_applies SET completed_at = datetime('now') WHERE run_id = '${expectedRun}';` }) });
  check('세션의 SQL 로는 완료 표시를 만들 수 없다', forged.status === 403, String(forged.status));
  const forgedRow = await fetch(`${PROXY}/query`, { method: 'POST', body: JSON.stringify({ sql: `INSERT INTO patrol_applies (run_id, statements) VALUES ('deadbeef', 1);` }) });
  check('세션의 SQL 로는 원장 행을 만들 수 없다', forgedRow.status === 403, String(forgedRow.status));

  // 5) 원장 해시는 내용에만 의존한다
  const same = createHash('sha256').update(readFileSync(path.join(dir, 'patrol-output.json'), 'utf8')).digest('hex').slice(0, 32);
  check('해시는 파일 내용으로만 정해진다', same === expectedRun);
} finally {
  await fetch(`${PROXY}/shutdown`, { method: 'POST' }).catch(() => {});
  proxy.kill();
  fake.close();
  rmSync(dir, { recursive: true, force: true });
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
