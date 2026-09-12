// Execute the actual reader through the production guard and SQLite schema.
// Copies keep generated state/logs out of the repository and never contact D1.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, copyFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const dir = mkdtempSync(path.join(tmpdir(), 'pz-read-state-'));
const db = new DatabaseSync(':memory:');
db.exec(readFileSync(new URL('../../site/schema.sql', import.meta.url), 'utf8'));
let queries = 0;
const upstream = createServer(async (req, res) => {
  try {
    let body = '';
    for await (const chunk of req) body += chunk;
    const results = db.prepare(JSON.parse(body).sql).all();
    queries++;
    res.end(JSON.stringify({ success: true, result: [{ results, meta: {} }] }));
  } catch (error) {
    res.statusCode = 400;
    res.end(JSON.stringify({ success: false, errors: [error.message] }));
  }
});
let proxy;
try {
  for (const file of ['read-state.mjs', 'd1.mjs', 'd1-proxy.mjs']) {
    copyFileSync(new URL(`../${file}`, import.meta.url), path.join(dir, file));
  }
  upstream.listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  proxy = spawn(process.execPath, [path.join(dir, 'd1-proxy.mjs')], {
    env: { ...process.env, PZ_D1_PROXY_PORT: '8795', PZ_D1_UPSTREAM: `http://127.0.0.1:${upstream.address().port}/` },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let log = '';
  proxy.stderr.on('data', chunk => { log += chunk; });
  proxy.stdin.end('test-token\n');
  const url = 'http://127.0.0.1:8795';
  let ready = false;
  for (let i = 0; i < 50; i++) {
    if (log.includes('listening on')) { ready = true; break; }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.ok(ready, log);
  const reader = spawn(process.execPath, [path.join(dir, 'read-state.mjs')], {
    env: { ...process.env, PZ_D1_PROXY: url }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let error = '';
  reader.stderr.on('data', chunk => { error += chunk; });
  const [code] = await once(reader, 'close');
  assert.equal(code, 0, error + log);
  const state = JSON.parse(readFileSync(path.join(dir, 'state.json'), 'utf8'));
  assert.equal(queries, 14, 'all state queries must reach SQLite');
  assert.equal(Object.keys(state).length, 15);
  for (const [key, value] of Object.entries(state)) {
    if (key !== 'read_at') assert.deepEqual(value, [], key);
  }
  const health = await (await fetch(`${url}/health`)).json();
  assert.equal(health.counters.refused, 0);
  console.log('PASS actual read-state queries through D1 guard and SQLite');
} finally {
  if (proxy && proxy.exitCode === null) {
    const closed = once(proxy, 'close');
    proxy.kill();
    await closed;
  }
  await new Promise(resolve => upstream.close(resolve));
  db.close();
  rmSync(dir, { recursive: true, force: true });
}
