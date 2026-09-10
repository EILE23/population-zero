// 토큰 계량 정확성 — 같은 usage 필드가 여러 청크에 걸쳐 재검사되며 중복 합산되면 안 된다.
// 예산이 실제보다 일찍 소진돼 순찰이 중단되는 사고를 막는 회귀 테스트.
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const NL = String.fromCharCode(10);
const PORT_UP = 8801, PORT_PROXY = 8802;

// 한 응답 안에서 input 120 / output 1 + 345 = 346 만 나온다.
// 경계 시험: usage 숫자가 청크 사이에서 잘리도록 일부러 쪼갠다.
const PIECES = [
  `event: message_start${NL}data: {"message":{"usage":{"input_tok`,
  `ens":120,"output_tokens":1}}}${NL}${NL}`,
  `event: ping${NL}data: {}${NL}${NL}`.repeat(8), // 사이에 usage 없는 청크가 많이 지나간다
  `event: message_delta${NL}data: {"usage":{"output_toke`,
  `ns":345}}${NL}${NL}event: done${NL}data: {}${NL}${NL}`,
];

const mock = createServer(async (req, res) => {
  for await (const _ of req) { /* drain */ }
  res.writeHead(200, { 'content-type': 'text/event-stream' });
  let i = 0;
  const tick = () => {
    if (i >= PIECES.length) return res.end();
    res.write(PIECES[i++]);
    setTimeout(tick, 20);
  };
  tick();
});
await new Promise((r) => mock.listen(PORT_UP, '127.0.0.1', r));

const proxy = spawn('node', [fileURLToPath(new URL('../anthropic-proxy.mjs', import.meta.url))], {
  env: { ...process.env, PZ_ANTHROPIC_UPSTREAM: `http://127.0.0.1:${PORT_UP}`, PZ_ANTHROPIC_PROXY_PORT: String(PORT_PROXY) },
  stdio: ['pipe', 'ignore', 'ignore'],
});
proxy.stdin.write(`T${NL}`);
for (let i = 0; i < 40; i++) { try { if ((await fetch(`http://127.0.0.1:${PORT_PROXY}/__health`)).ok) break; } catch { /* wait */ } await new Promise((r) => setTimeout(r, 150)); }

const res = await fetch(`http://127.0.0.1:${PORT_PROXY}/v1/messages`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ model: 'claude-sonnet-4-5', max_tokens: 1024, stream: true }),
});
const body = await res.text();
await new Promise((r) => setTimeout(r, 300));
const { tokens } = await (await fetch(`http://127.0.0.1:${PORT_PROXY}/__health`)).json();

let fail = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${extra}`); if (!ok) fail++; };
check('response passed through intact', body.includes('event: done') && body.includes('"output_tokens":345'));
check('input counted once', tokens.input === 120, ` (got ${tokens.input}, want 120)`);
check('output counted once', tokens.output === 346, ` (got ${tokens.output}, want 346)`);

await fetch(`http://127.0.0.1:${PORT_PROXY}/__shutdown`, { method: 'POST' }).catch(() => {});
mock.close();
console.log(fail ? `${NL}${fail} failed` : `${NL}all passed`);
process.exit(fail ? 1 : 0);
