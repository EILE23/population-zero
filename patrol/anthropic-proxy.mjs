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
// 엔드포인트만 막으면 '토큰 유출'은 막아도 '크레딧 소진'은 못 막는다 — 요청 내용과 누적 사용량에도 상한을 건다.
// 값은 정상 순찰(요청 수십 회, 출력 수만 토큰)의 10배 이상 여유를 두되, 폭주는 확실히 끊는 선.
// 실측(2026-09-10 full 순찰): 요청 63회, 입력 22K·출력 40K 토큰. 아래 값은 그 10~30배 여유다.
const LIMITS = {
  requests: 600,
  bodyBytes: 8 * 1024 * 1024, // 요청 하나가 이보다 크면 정상 순찰이 아니다
  maxTokensPerRequest: 64_000,
  inputTokens: 20_000_000,  // 프롬프트 캐시 재사용이 많아 입력은 크게 잡는다
  outputTokens: 1_500_000,
};
// 모델은 Claude 계열만 — 정확한 id 목록으로 좁히면 Claude Code 가 기본 모델을 올릴 때 순찰이 통째로 멈춘다.
// 대신 실제로 쓰인 모델을 한 번씩 로그에 남겨, 운영 기록을 보고 나중에 좁힐 수 있게 한다.
const MODEL_ALLOWED = /^claude-(haiku|sonnet|opus|fable|mythos)-[0-9]/;
const seenModels = new Set();
const usage = { input: 0, output: 0 };
// 누적 토큰은 응답을 받아야 알 수 있어서, 예산 직전의 큰 요청 하나가 한도를 크게 넘길 수 있다.
// 보내기 전에 본문 크기로 입력량을 어림잡아(영문·JSON 기준 대략 4바이트/토큰) 미리 막는다.
const estimateInputTokens = (bytes) => Math.ceil(bytes / 4);

// 응답에서 토큰 사용량을 읽어 누적한다. 스트리밍이면 SSE 를 훑고(전달 내용은 그대로), 아니면 JSON 을 본다.
// 청크 경계에서 숫자가 잘리지 않도록 꼬리를 조금 남겨 이어 붙인다.
const TOKEN_FIELD = /"(input|output)_tokens"\s*:\s*(\d+)/g;
const CARRY = 64; // 잘린 패턴을 이어 붙일 만큼만 남긴다 ("output_tokens": 123 보다 넉넉)

function meterStream() {
  const decoder = new TextDecoder();
  let buf = ''; // 아직 다 훑지 않은 꼬리만 들고 있는다 (응답 전체를 쌓지 않는다)
  return new TransformStream({
    transform(chunk, controller) {
      controller.enqueue(chunk); // 전달은 손대지 않는다 — 계량만 곁다리로 한다
      buf += decoder.decode(chunk, { stream: true });
      TOKEN_FIELD.lastIndex = 0;
      let m, consumed = 0;
      while ((m = TOKEN_FIELD.exec(buf))) {
        if (m[1] === 'input') usage.input += Number(m[2]); else usage.output += Number(m[2]);
        consumed = TOKEN_FIELD.lastIndex; // 여기까지는 세었다 — 다음 청크에서 다시 세지 않는다
      }
      // 이미 센 부분은 버리고, 그 뒤에는 완전한 매치가 없으니 잘림 대비 꼬리만 남긴다
      buf = buf.slice(Math.max(consumed, buf.length - CARRY));
    },
  });
}

const server = createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/__health') { res.writeHead(200, { 'content-type': 'application/json' }); return res.end(JSON.stringify({ ok: true, counters, tokens: usage })); }
  if (req.method === 'POST' && req.url === '/__shutdown') { res.writeHead(200); res.end('bye'); log(`shutdown ${JSON.stringify({ ...counters, tokens: usage })}`); setTimeout(() => process.exit(0), 100); return; }

  const deny = (code, msg) => {
    counters.refused++;
    log(`REFUSED ${req.method} ${req.url.split('?')[0]}: ${msg}`);
    res.writeHead(code, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ type: 'error', error: { type: 'permission_error', message: `patrol gateway: ${msg}` } }));
  };
  if (!ALLOW.some((a) => a.method === req.method && a.path.test(req.url))) return deny(403, 'endpoint not allowed');
  if (counters.requests >= LIMITS.requests) return deny(429, 'request budget exhausted');
  if (usage.input >= LIMITS.inputTokens || usage.output >= LIMITS.outputTokens) return deny(429, `token budget exhausted (in ${usage.input}, out ${usage.output})`);

  const started = Date.now();
  counters.requests++;
  const chunks = [];
  let size = 0;
  for await (const c of req) { size += c.length; if (size > LIMITS.bodyBytes) return deny(413, 'body too large'); chunks.push(c); }
  const body = chunks.length ? Buffer.concat(chunks) : undefined;

  // 추론 요청은 본문도 본다 — 모델과 1회 출력 상한을 강제한다 (도구 정의·프롬프트 내용에는 관여하지 않는다)
  if (req.method === 'POST' && body && req.url.startsWith('/v1/messages')) {
    let payload;
    try { payload = JSON.parse(body.toString('utf8')); } catch { return deny(400, 'unparseable request body'); }
    if (typeof payload?.model !== 'string' || !MODEL_ALLOWED.test(payload.model)) return deny(403, `model not allowed: ${String(payload?.model).slice(0, 60)}`);
    if (Number(payload?.max_tokens) > LIMITS.maxTokensPerRequest) return deny(403, `max_tokens ${payload.max_tokens} over cap ${LIMITS.maxTokensPerRequest}`);
    // 보내기 전 어림 검사 — 응답 후 계량만으로는 마지막 한 방을 못 막는다
    const projectedIn = usage.input + estimateInputTokens(body.length);
    if (projectedIn > LIMITS.inputTokens) return deny(429, `projected input ${projectedIn} over budget ${LIMITS.inputTokens}`);
    const projectedOut = usage.output + Math.min(Number(payload?.max_tokens) || 0, LIMITS.maxTokensPerRequest);
    if (projectedOut > LIMITS.outputTokens) return deny(429, `projected output ${projectedOut} over budget ${LIMITS.outputTokens}`);
    if (!seenModels.has(payload.model)) { seenModels.add(payload.model); log(`model in use: ${payload.model}`); }
  }

  const headers = {};
  for (const [k, v] of Object.entries(req.headers)) if (!HOP.has(k.toLowerCase()) && v != null) headers[k] = Array.isArray(v) ? v.join(', ') : v;
  headers.authorization = `Bearer ${token}`;
  headers['accept-encoding'] = 'identity'; // no compression, so the stream can be piped back untouched

  try {
    const up = await fetch(UPSTREAM + req.url, { method: req.method, headers, body, redirect: 'manual' });
    const out = {};
    for (const [k, v] of up.headers) if (!['content-encoding', 'transfer-encoding', 'connection', 'content-length'].includes(k)) out[k] = v;
    res.writeHead(up.status, out);
    if (up.body) Readable.fromWeb(up.body.pipeThrough(meterStream())).pipe(res); else res.end();
    res.on('finish', () => log(`${req.method} ${req.url.split('?')[0]} ${up.status} ${Date.now() - started}ms (tok in ${usage.input} out ${usage.output})`));
    if (up.status >= 400) counters.errors++;
  } catch (e) {
    counters.errors++;
    log(`ERROR ${req.method} ${req.url.split('?')[0]}: ${e.message.slice(0, 200)}`);
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: { type: 'gateway_error', message: e.message.slice(0, 200) } }));
  }
});

server.listen(PORT, '127.0.0.1', () => log(`anthropic-proxy listening on 127.0.0.1:${PORT} → ${UPSTREAM}`));
