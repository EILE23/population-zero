// Anthropic API gateway for the patrol session — holds the Claude OAuth token so the session never sees it.
//
// Start (CI):  printf '%s\n' "$CLAUDE_CODE_OAUTH_TOKEN" | node anthropic-proxy.mjs
// Session env: CLAUDE_CODE_OAUTH_TOKEN=<placeholder>  ANTHROPIC_BASE_URL=http://127.0.0.1:8788
//
// Claude Code sends every API request to ANTHROPIC_BASE_URL with `Authorization: Bearer <placeholder>`;
// this gateway swaps in the real token and forwards to api.anthropic.com, streaming the response back.
// Nothing about the request or response is logged beyond method, path, status and timing.
//
// Two layers, because hiding the token is not the same as containing it: the session can still reach
// this port, so the gateway also narrows what the token may do — only the inference endpoints Claude
// Code needs, under a request budget. Account, organization, batch and file APIs are refused.
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { appendFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const PORT = Number(process.env.PZ_ANTHROPIC_PROXY_PORT || 8788);
const UPSTREAM = process.env.PZ_ANTHROPIC_UPSTREAM || 'https://api.anthropic.com';
const LOG = path.join(path.dirname(fileURLToPath(import.meta.url)), 'logs', 'anthropic-proxy.log');

const token = await new Promise((resolve) => {
  let buf = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (d) => { buf += d; if (buf.includes('\n')) { process.stdin.pause(); resolve(buf.split('\n')[0].trim()); } });
  process.stdin.on('end', () => resolve(buf.trim()));
});
if (!token) { console.error('anthropic-proxy: no token on stdin'); process.exit(1); }
for (const k of Object.keys(process.env)) if (/TOKEN|SECRET|KEY|PAT$|PASSWORD/i.test(k)) delete process.env[k];

mkdirSync(path.dirname(LOG), { recursive: true });
const log = (line) => { const l = `${new Date().toISOString()} ${line}`; console.error(l); try { appendFileSync(LOG, l + '\n'); } catch { /* ignore */ } };
const counters = { requests: 0, errors: 0, refused: 0 };
const HOP = new Set(['host', 'connection', 'content-length', 'transfer-encoding', 'keep-alive', 'accept-encoding', 'authorization', 'x-api-key']);

// 토큰을 숨기는 것만으로는 부족하다 — 세션은 이 포트에 접근할 수 있으므로, 토큰의 '권한' 자체를 좁힌다.
// Claude Code 가 실제로 쓰는 추론 경로만 통과시키고, 계정·조직·배치·파일 API 는 막는다.
const ALLOW = [
  { method: 'POST', path: /^\/v1\/messages(\?.*)?$/ },
  { method: 'POST', path: /^\/v1\/messages\/count_tokens(\?.*)?$/ },
  { method: 'GET', path: /^\/v1\/models(\/[A-Za-z0-9._-]+)?(\?.*)?$/ },
  { method: 'HEAD', path: /^\/api\/hello$/ }, // Claude Code 연결 확인 (본문 없는 no-op)
  { method: 'GET', path: /^\/api\/hello$/ },
];
const LIMITS = { requests: 3000, bodyBytes: 32 * 1024 * 1024 }; // 순찰 1회 분량을 크게 웃도는 상한 — 크레딧 소진 방어

const server = createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/__health') { res.writeHead(200, { 'content-type': 'application/json' }); return res.end(JSON.stringify({ ok: true, counters })); }
  if (req.method === 'POST' && req.url === '/__shutdown') { res.writeHead(200); res.end('bye'); log(`shutdown ${JSON.stringify(counters)}`); setTimeout(() => process.exit(0), 100); return; }

  const deny = (code, msg) => {
    counters.refused++;
    log(`REFUSED ${req.method} ${req.url.split('?')[0]}: ${msg}`);
    res.writeHead(code, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ type: 'error', error: { type: 'permission_error', message: `patrol gateway: ${msg}` } }));
  };
  if (!ALLOW.some((a) => a.method === req.method && a.path.test(req.url))) return deny(403, 'endpoint not allowed');
  if (counters.requests >= LIMITS.requests) return deny(429, 'request budget exhausted');

  const started = Date.now();
  counters.requests++;
  const chunks = [];
  let size = 0;
  for await (const c of req) { size += c.length; if (size > LIMITS.bodyBytes) return deny(413, 'body too large'); chunks.push(c); }
  const body = chunks.length ? Buffer.concat(chunks) : undefined;

  const headers = {};
  for (const [k, v] of Object.entries(req.headers)) if (!HOP.has(k.toLowerCase()) && v != null) headers[k] = Array.isArray(v) ? v.join(', ') : v;
  headers.authorization = `Bearer ${token}`;
  headers['accept-encoding'] = 'identity'; // no compression, so the stream can be piped back untouched

  try {
    const up = await fetch(UPSTREAM + req.url, { method: req.method, headers, body, redirect: 'manual' });
    const out = {};
    for (const [k, v] of up.headers) if (!['content-encoding', 'transfer-encoding', 'connection', 'content-length'].includes(k)) out[k] = v;
    res.writeHead(up.status, out);
    if (up.body) Readable.fromWeb(up.body).pipe(res); else res.end();
    res.on('finish', () => log(`${req.method} ${req.url.split('?')[0]} ${up.status} ${Date.now() - started}ms`));
    if (up.status >= 400) counters.errors++;
  } catch (e) {
    counters.errors++;
    log(`ERROR ${req.method} ${req.url.split('?')[0]}: ${e.message.slice(0, 200)}`);
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: { type: 'gateway_error', message: e.message.slice(0, 200) } }));
  }
});

server.listen(PORT, '127.0.0.1', () => log(`anthropic-proxy listening on 127.0.0.1:${PORT} → ${UPSTREAM}`));
