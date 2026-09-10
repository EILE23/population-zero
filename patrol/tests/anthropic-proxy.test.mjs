// anthropic-proxy 검증: 엔드포인트 허용목록 + 모델/토큰 상한 + 헤더 교체 + SSE 스트리밍 + 토큰 계량 + 비노출
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const NL = String.fromCharCode(10);
const SSE_START = `event: message_start${NL}data: {"message":{"usage":{"input_tokens":120,"output_tokens":1}}}${NL}${NL}`;
const SSE_MID = `event: b${NL}data: {"n":2}${NL}${NL}`;
const SSE_END = `event: message_delta${NL}data: {"usage":{"output_tokens":345}}${NL}${NL}event: done${NL}data: {}${NL}${NL}`;

const seen = [];
const mock = createServer(async (req, res) => {
  let b = ''; for await (const c of req) b += c;
  seen.push({ auth: req.headers.authorization, beta: req.headers['anthropic-beta'], enc: req.headers['accept-encoding'], body: b, url: req.url });
  res.writeHead(200, { 'content-type': 'text/event-stream' });
  res.write(SSE_START);
  setTimeout(() => res.write(SSE_MID), 100);
  setTimeout(() => { res.write(SSE_END); res.end(); }, 200);
});
await new Promise((r) => mock.listen(8795, '127.0.0.1', r));

const p = spawn('node', [fileURLToPath(new URL('../anthropic-proxy.mjs', import.meta.url))], {
  env: { ...process.env, PZ_ANTHROPIC_UPSTREAM: 'http://127.0.0.1:8795', PZ_ANTHROPIC_PROXY_PORT: '8796', CLAUDE_CODE_OAUTH_TOKEN: 'ENV-LEAK' },
  stdio: ['pipe', 'inherit', 'pipe'],
});
p.stdin.write(`REAL-OAUTH-TOKEN${NL}`);
let err = ''; p.stderr.on('data', (d) => { err += d; });
for (let i = 0; i < 40; i++) { try { if ((await fetch('http://127.0.0.1:8796/__health')).ok) break; } catch { /* wait */ } await new Promise((r) => setTimeout(r, 150)); }

let fail = 0;
const check = (name, ok) => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`); if (!ok) fail++; };

// ── 1. 엔드포인트 허용목록 ──
const VALID = JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 1024 });
const probe = async (method, path, expected) => {
  const before = seen.length;
  const r = await fetch('http://127.0.0.1:8796' + path, {
    method, headers: { authorization: 'Bearer placeholder', 'content-type': 'application/json' },
    body: method === 'POST' ? VALID : undefined,
  });
  const forwarded = seen.length > before;
  check(`${method} ${path} -> ${r.status}${forwarded ? ' (forwarded)' : ' (blocked)'}`,
    r.status === expected && (expected === 200 ? forwarded : !forwarded));
};
await probe('POST', '/v1/messages', 200);
await probe('POST', '/v1/messages/count_tokens', 200);
await probe('GET', '/v1/models', 200);
await probe('HEAD', '/api/hello', 200);
await probe('POST', '/v1/organizations/me/api_keys', 403);
await probe('GET', '/v1/organizations/usage_report/messages', 403);
await probe('POST', '/v1/messages/batches', 403);
await probe('POST', '/v1/files', 403);
await probe('DELETE', '/v1/messages', 403);

// ── 2. 모델·max_tokens 상한 ──
const post = async (name, payload, expected) => {
  const before = seen.length;
  const r = await fetch('http://127.0.0.1:8796/v1/messages', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: typeof payload === 'string' ? payload : JSON.stringify(payload),
  });
  const forwarded = seen.length > before;
  check(`${name} -> ${r.status}${forwarded ? ' (forwarded)' : ' (blocked)'}`,
    r.status === expected && (expected === 200 ? forwarded : !forwarded));
};
await post('allowed model', { model: 'claude-sonnet-4-5', max_tokens: 8000 }, 200);
await post('allowed model (haiku)', { model: 'claude-haiku-4-5-20251001', max_tokens: 1024 }, 200);
await post('unknown model refused', { model: 'gpt-4o', max_tokens: 100 }, 403);
await post('missing model refused', { max_tokens: 100 }, 403);
await post('max_tokens over cap refused', { model: 'claude-opus-5', max_tokens: 200000 }, 403);
await post('unparseable body refused', '{not json at all', 400);

// ── 3. 헤더 교체 · 스트리밍 ──
const t0 = Date.now();
const res = await fetch('http://127.0.0.1:8796/v1/messages?beta=true', {
  method: 'POST',
  headers: { authorization: 'Bearer sk-ant-oat01-placeholder', 'anthropic-beta': 'oauth-2025-04-20', 'anthropic-version': '2023-06-01', 'content-type': 'application/json', 'accept-encoding': 'gzip' },
  body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 4096, stream: true }),
});
const chunks = [];
const reader = res.body.getReader();
const dec = new TextDecoder();
while (true) { const { value, done } = await reader.read(); if (done) break; chunks.push({ t: Date.now() - t0, s: dec.decode(value) }); }
const s = seen[seen.length - 1];

check('status 200', res.status === 200);
check('content-type streamed', (res.headers.get('content-type') || '').includes('event-stream'));
check('auth replaced with real token', s.auth === 'Bearer REAL-OAUTH-TOKEN');
check('beta header forwarded', s.beta === 'oauth-2025-04-20');
check('path+query forwarded', s.url === '/v1/messages?beta=true');
check('body forwarded', s.body.includes('"stream":true'));
check('no compression requested', s.enc === 'identity');
check('streamed incrementally', chunks.length >= 2 && chunks[chunks.length - 1].t >= 150);
check('all events received', chunks.map((c) => c.s).join('').includes('event: done'));

// ── 4. 토큰 계량 · 비노출 ──
await new Promise((r) => setTimeout(r, 400));
const health = await (await fetch('http://127.0.0.1:8796/__health')).json();
check(`token usage metered (in ${health.tokens.input}, out ${health.tokens.output})`, health.tokens.output > 0 && health.tokens.input > 0);
check('env token not echoed', !err.includes('ENV-LEAK') && !err.includes('REAL-OAUTH'));

await fetch('http://127.0.0.1:8796/__shutdown', { method: 'POST' });
mock.close();
console.log(fail ? `${NL}${fail} failed` : `${NL}all passed`);
process.exit(fail ? 1 : 0);
