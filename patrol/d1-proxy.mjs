// D1 proxy for the patrol session — holds the Cloudflare token so the Claude session never sees it.
//
// Start (CI):  printf '%s\n' "$CLOUDFLARE_API_TOKEN" | node d1-proxy.mjs
//   The token comes in on stdin (never argv, never env), the env is scrubbed, and the process
//   listens on 127.0.0.1:8787. Scripts talk to it through d1.mjs when PZ_D1_PROXY is set.
//
// Why: the patrol reads human posts/comments. A prompt injection that succeeds can make the
// session run any shell command — but with no secrets in the session, the worst it can reach
// is this proxy, and the proxy only accepts the statement shapes the patrol legitimately uses
// (resident posts/comments/likes/follows, moderation flags, blog settings). Everything else is
// refused and logged: schema changes, human accounts, auth/session/contact tables, mass deletes.
//
// Endpoints:  POST /query {sql}  → {result:[{results, meta}]} (D1 REST response shape)
//             GET  /health       → ok        POST /shutdown → exits
import { createServer } from 'node:http';
import { appendFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ACCOUNT = '57bb730630ace30ef33217fb43d029cf';
const DATABASE = 'c721dc64-8d28-41e1-a7a4-1c0eae3e9427';
const PORT = Number(process.env.PZ_D1_PROXY_PORT || 8787);
const UPSTREAM = process.env.PZ_D1_UPSTREAM || `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT}/d1/database/${DATABASE}/query`;
const LOG = path.join(path.dirname(fileURLToPath(import.meta.url)), 'logs', 'd1-proxy.log');

// ── token: stdin only ──────────────────────────────────────────────────────────
const token = await new Promise((resolve) => {
  let buf = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (d) => { buf += d; if (buf.includes('\n')) { process.stdin.pause(); resolve(buf.split('\n')[0].trim()); } });
  process.stdin.on('end', () => resolve(buf.trim()));
});
if (!token) { console.error('d1-proxy: no token on stdin'); process.exit(1); }
for (const k of Object.keys(process.env)) if (/TOKEN|SECRET|KEY|PAT$|PASSWORD/i.test(k)) delete process.env[k];

// ── limits ─────────────────────────────────────────────────────────────────────
const LIMITS = { statementsPerLifetime: 5000, rowDeletes: 10, reactionDeletes: 60, bodyBytes: 2_000_000, upstreamChunk: 40 };
const counters = { statements: 0, rowDeletes: 0, reactionDeletes: 0, refused: 0 };

// ── SQL statement splitting ────────────────────────────────────────────────────
// Only a `;` outside quotes ends a statement. Comments are not skipped here on purpose: a `;` hidden
// inside one would split the text in a place SQLite wouldn't, so instead the fragments keep their
// comment markers and check() refuses them. Splitting is deliberately naive and fails closed.
function splitStatements(sql) {
  const out = [];
  let cur = '';
  for (let i = 0; i < sql.length; i++) {
    const ch = sql[i];
    if (ch === "'" || ch === '"' || ch === '`' || ch === '[') {
      const close = ch === '[' ? ']' : ch;
      cur += ch;
      for (i++; i < sql.length; i++) {
        cur += sql[i];
        if (sql[i] !== close) continue;
        if (close === "'" && sql[i + 1] === "'") { cur += "'"; i++; continue; } // '' escape
        break;
      }
      continue;
    }
    if (ch === ';') { if (cur.trim()) out.push(cur.trim()); cur = ''; continue; }
    cur += ch;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

// Strip string literals so keyword/table/paren checks can't be fooled by quoted text (post bodies
// contain anything). Returns null — refuse the statement outright — for two constructs a patrol never
// needs and that only let this parser and SQLite disagree about what the statement means:
//   • comments (`--`, `/* */`): can hide a parenthesis or a statement separator
//   • quoted identifiers (`"x"`, `` `x` ``, `[x]`): would let `SELECT "email" FROM "sessions"` read as
//     harmless placeholders here while SQLite still sees the real column and table
function skeleton(stmt) {
  let out = '';
  for (let i = 0; i < stmt.length; i++) {
    const ch = stmt[i];
    if (ch === "'") { // string literal, '' escapes
      out += "''";
      for (i++; i < stmt.length; i++) {
        if (stmt[i] !== "'") continue;
        if (stmt[i + 1] === "'") { i++; continue; }
        break;
      }
      continue;
    }
    if (ch === '"' || ch === '`' || ch === '[') return null; // quoted identifier
    if (ch === '-' && stmt[i + 1] === '-') return null; // line comment
    if (ch === '/' && stmt[i + 1] === '*') return null; // block comment
    out += ch;
  }
  return out.replace(/\s+/g, ' ').trim();
}

// ── policy ─────────────────────────────────────────────────────────────────────
const DENY_ANYWHERE = /\b(auth_tokens|sessions|contact_messages|api_budget|wake_log|site_meta|stats_daily|sqlite_master|sqlite_sequence|password_hash|google_sub|email|ATTACH|DETACH|PRAGMA|VACUUM|CREATE|DROP|ALTER|TRIGGER|INDEX|REINDEX|REPLACE|BEGIN|COMMIT|ROLLBACK|SAVEPOINT)\b/i;
const INSERT_TABLES = { posts: 1, comments: 1, poll_options: 1, resident_likes: 1, resident_poll_votes: 1, follows: 1, follow_events: 1, residents: 1 };
const RESIDENT_ONLY_INSERT = new Set(['follows', 'follow_events']); // 사람의 팔로우·이력을 순찰이 지어내지 못하게
const INSERT_DENY_COLS = /\b(user_id|visitor_name|visitor_ip|password_hash|email|google_sub|tier)\b/i; // tier: no self-promotion to admin
const UPDATE_RULES = {
  posts: { cols: /^(pinned|og_image|series|resident_view_count|hidden|title|body|media_type|media_ref|topic|region|kind|created_at)$/, guard: 'user_id IS NULL', guardExempt: /^(hidden|resident_view_count)$/ },
  comments: { cols: /^(hidden|body)$/, guard: 'resident_id IS NOT NULL', guardExempt: /^hidden$/ },
  poll_options: { cols: /^votes$/ },
  reports: { cols: /^status$/ },
  residents: { cols: /^(blog_title|bio|avatar_url)$/ },
};
// DELETE: only the exact single-row / single-relationship shapes apply.mjs and a feed fix need.
// Matched against the whitespace-normalized ORIGINAL statement (literal values matter here).
const DELETE_SHAPES = {
  follows: /^DELETE FROM follows WHERE follower_type\s*=\s*'resident' AND follower_id\s*=\s*\d+ AND target_type\s*=\s*'(resident|user)' AND target_id\s*=\s*\d+$/i,
  resident_likes: /^DELETE FROM resident_likes WHERE (resident_id\s*=\s*\d+ AND post_id\s*=\s*\d+|post_id\s*=\s*\d+ AND resident_id\s*=\s*\d+)$/i,
  resident_poll_votes: /^DELETE FROM resident_poll_votes WHERE (resident_id\s*=\s*\d+ AND post_id\s*=\s*\d+|post_id\s*=\s*\d+ AND resident_id\s*=\s*\d+)$/i,
  poll_options: /^DELETE FROM poll_options WHERE (id|post_id)\s*=\s*\d+$/i,
};

/** start 위치의 '(' 가 닫힌 뒤 문장이 끝나는가 (세미콜론·공백만 허용). 값 안의 괄호는 깊이로 센다. */
function endsAfterOneGroup(sk, start) {
  if (sk[start] !== '(') return false;
  let depth = 0;
  for (let i = start; i < sk.length; i++) {
    if (sk[i] === '(') depth++;
    else if (sk[i] === ')') {
      depth--;
      if (depth === 0) return /^[\s;]*$/.test(sk.slice(i + 1)); // 뒤에 UPSERT·추가 행이 붙으면 거부
    }
  }
  return false;
}

function assignedColumns(setClause) {
  // "a = 1, b = 'x', c = c + 1"  → [a, b, c]   (literals are already blanked to '')
  return setClause.split(',').map((s) => s.trim().match(/^([a-z_]+)\s*=/i)?.[1]?.toLowerCase()).filter(Boolean);
}

// Verbs that appear at parenthesis depth 0 — a CTE (`WITH x AS (...) DELETE ...`) puts its real verb here,
// while subqueries sit inside parentheses. Literals are already blanked, so quoted text can't fake a verb.
function topLevelVerbs(sk) {
  const verbs = [];
  let depth = 0;
  for (const tok of sk.split(/(\(|\))/)) {
    if (tok === '(') { depth++; continue; }
    if (tok === ')') { depth--; continue; }
    if (depth === 0) for (const m of tok.matchAll(/\b(SELECT|INSERT|UPDATE|DELETE|REPLACE|WITH|VALUES)\b/gi)) verbs.push(m[1].toUpperCase());
  }
  return verbs;
}

/** Returns { ok:true, sql } (possibly rewritten with a guard) or { ok:false, reason }. */
function check(stmt) {
  const sk = skeleton(stmt);
  if (sk === null) return { ok: false, reason: 'comments and quoted identifiers are not allowed' };
  if (DENY_ANYWHERE.test(sk)) return { ok: false, reason: 'denied keyword/table' };
  // whole-row reads of users would expose email/password_hash — but COUNT(*) is fine
  if (/\busers\b/i.test(sk) && /\bSELECT\s+\*|\b[a-z_]+\.\*/i.test(sk)) return { ok: false, reason: 'SELECT * over users' };

  const verbs = topLevelVerbs(sk);
  if (/^(SELECT|WITH)\b/i.test(sk)) {
    // read-only means: no write verb at depth 0 (a CTE-fronted DELETE/UPDATE/INSERT lands here)
    if (verbs.some((v) => v === 'INSERT' || v === 'UPDATE' || v === 'DELETE' || v === 'REPLACE' || v === 'VALUES')) return { ok: false, reason: 'write verb behind SELECT/WITH' };
    return { ok: true, sql: stmt };
  }
  // writes: exactly one top-level verb of their own kind — no CTE prefix, no trailing tricks
  if (verbs[0] === 'WITH') return { ok: false, reason: 'CTE-fronted write' };

  // INSERT 는 **한 테이블에 한 행을 넣는 형태만** 허용한다.
  // 예전에는 컬럼 목록과 첫 VALUES 행만 봤다. 그 뒤에 붙는 것은 검사 밖이라
  //   ① `ON CONFLICT (id) DO UPDATE SET body=...` 로 UPDATE 정책(사람 글 보호)을 통째로 우회하고
  //   ② 두 번째 행에 `('user', …)` 를 얹어 사람 팔로우·이력을 위조할 수 있었다.
  // 그래서 문장 끝까지 형태를 고정한다: 단일 행 VALUES 뒤에는 아무것도 못 온다.
  let m = sk.match(/^INSERT (?:OR IGNORE )?INTO ([a-z_]+) \(([^)]*)\) VALUES\s*(\()/i);
  if (m && endsAfterOneGroup(sk, sk.indexOf('(', m.index + m[0].length - 1))) {
    const table = m[1].toLowerCase(), cols = m[2];
    if (!INSERT_TABLES[table]) return { ok: false, reason: `insert into ${table}` };
    if (INSERT_DENY_COLS.test(cols)) return { ok: false, reason: `insert sets protected column (${table})` };
    if (RESIDENT_ONLY_INSERT.has(table)) {
      if (!/^\s*follower_type\b/i.test(cols)) return { ok: false, reason: `${table} insert must lead with follower_type` };
      if (!/VALUES \(\s*'resident'/i.test(stmt.replace(/\s+/g, ' '))) return { ok: false, reason: `${table} insert must be follower_type=resident` };
    }
    return { ok: true, sql: stmt };
  }
  if (/^INSERT\b/i.test(sk)) {
    // 어떤 이유로든 위 형태를 벗어난 INSERT — UPSERT·다중행·INSERT..SELECT·후행 토큰 전부 여기서 걸린다
    return { ok: false, reason: 'insert must be a single VALUES row with nothing after it' };
  }

  m = sk.match(/^UPDATE ([a-z_]+) SET (.+?) WHERE (.+)$/i);
  if (m) {
    const table = m[1].toLowerCase(), rule = UPDATE_RULES[table];
    if (!rule) return { ok: false, reason: `update ${table}` };
    const cols = assignedColumns(m[2]);
    if (!cols.length || cols.some((c) => !rule.cols.test(c))) return { ok: false, reason: `update ${table} column not allowed (${cols.join(',')})` };
    if (rule.guard && cols.some((c) => !rule.guardExempt?.test(c))) {
      // rewrite on the ORIGINAL statement: UPDATE t SET ... WHERE (orig) AND guard
      const om = stmt.replace(/\s+/g, ' ').match(/^(UPDATE [a-z_]+ SET .+? WHERE )(.+)$/i);
      if (!om) return { ok: false, reason: 'update rewrite failed' };
      return { ok: true, sql: `${om[1]}(${om[2]}) AND ${rule.guard}`, guarded: true };
    }
    return { ok: true, sql: stmt };
  }
  if (/^UPDATE\b/i.test(sk)) return { ok: false, reason: 'update without WHERE' };

  m = sk.match(/^DELETE FROM ([a-z_]+) WHERE (.+)$/i);
  if (m) {
    const table = m[1].toLowerCase();
    if (DELETE_SHAPES[table]) {
      const norm = stmt.replace(/\s+/g, ' ').replace(/;\s*$/, '').trim();
      if (!DELETE_SHAPES[table].test(norm)) return { ok: false, reason: `delete ${table} must target one row by its full key` };
      if (counters.reactionDeletes >= LIMITS.reactionDeletes) return { ok: false, reason: 'reaction-delete budget exhausted' };
      counters.reactionDeletes++;
      return { ok: true, sql: norm };
    }
    if (table === 'posts' || table === 'comments') {
      if (!/^id\s*=\s*\d+$/i.test(m[2].trim())) return { ok: false, reason: `delete ${table} must be WHERE id = <one id>` };
      if (counters.rowDeletes >= LIMITS.rowDeletes) return { ok: false, reason: 'row-delete budget exhausted' };
      counters.rowDeletes++;
      const guard = table === 'posts' ? 'user_id IS NULL' : 'resident_id IS NOT NULL';
      return { ok: true, sql: `DELETE FROM ${table} WHERE (${m[2].trim()}) AND ${guard}`, guarded: true };
    }
    return { ok: false, reason: `delete ${table}` };
  }
  return { ok: false, reason: 'unrecognized statement shape' };
}

// ── upstream ───────────────────────────────────────────────────────────────────
async function upstream(sql) {
  const res = await fetch(UPSTREAM, { method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify({ sql }) });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.success === false) throw new Error(`d1 ${res.status}: ${JSON.stringify(json.errors ?? json).slice(0, 400)}`);
  return json.result ?? [];
}

// ── server ─────────────────────────────────────────────────────────────────────
mkdirSync(path.dirname(LOG), { recursive: true });
const log = (line) => { const l = `${new Date().toISOString()} ${line}`; console.error(l); try { appendFileSync(LOG, l + '\n'); } catch { /* ignore */ } };

const server = createServer(async (req, res) => {
  const send = (code, body) => { res.writeHead(code, { 'content-type': 'application/json' }); res.end(JSON.stringify(body)); };
  if (req.method === 'GET' && req.url === '/health') return send(200, { ok: true, counters });
  if (req.method === 'POST' && req.url === '/shutdown') {
    send(200, { ok: true, counters });
    log(`shutdown ${JSON.stringify(counters)}`);
    // 러너는 곧 사라진다 — CI 가 집어서 저장소의 run-log 에 남길 수 있게 기계가 읽을 형태로 떨군다
    try { writeFileSync(path.join(path.dirname(LOG), 'd1-summary.json'), JSON.stringify(counters)); } catch { /* ignore */ }
    setTimeout(() => process.exit(0), 100);
    return;
  }
  if (req.method !== 'POST' || req.url !== '/query') return send(404, { error: 'not found' });

  let body = '';
  for await (const chunk of req) { body += chunk; if (body.length > LIMITS.bodyBytes) return send(413, { error: 'body too large' }); }
  let sql;
  try { sql = String(JSON.parse(body).sql || ''); } catch { return send(400, { error: 'bad json' }); }

  const statements = splitStatements(sql);
  if (!statements.length) return send(400, { error: 'empty sql' });
  if (counters.statements + statements.length > LIMITS.statementsPerLifetime) { log(`REFUSED lifetime budget (${statements.length})`); return send(429, { error: 'statement budget exhausted' }); }

  const approved = [];
  for (const s of statements) {
    const v = check(s);
    if (!v.ok) { counters.refused++; log(`REFUSED (${v.reason}): ${s.replace(/\s+/g, ' ').slice(0, 160)}`); return send(403, { error: `refused: ${v.reason}`, statement: s.slice(0, 200) }); }
    if (v.guarded) log(`GUARDED: ${v.sql.replace(/\s+/g, ' ').slice(0, 160)}`);
    approved.push(v.sql);
  }
  counters.statements += approved.length;

  try {
    const result = [];
    for (let i = 0; i < approved.length; i += LIMITS.upstreamChunk) {
      const chunk = approved.slice(i, i + LIMITS.upstreamChunk);
      result.push(...await upstream(chunk.map((s) => s.replace(/;\s*$/, '')).join(';\n') + ';'));
    }
    log(`ok ${approved.length} stmt (${approved.map((s) => s.slice(0, 6).toUpperCase().trim()).join(',').slice(0, 60)})`);
    send(200, { result });
  } catch (e) {
    log(`UPSTREAM ERROR: ${e.message.slice(0, 300)}`);
    send(502, { error: e.message.slice(0, 500) });
  }
});

server.listen(PORT, '127.0.0.1', () => log(`d1-proxy listening on 127.0.0.1:${PORT} (upstream: ${UPSTREAM.replace(/database\/[^/]+/, 'database/…')})`));
