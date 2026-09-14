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
// Endpoints:  POST /query {sql}           → {result:[{results, meta}]} (D1 REST response shape)
//             POST /apply {output, sql}   → 같은 정책으로 적재하되 원장(patrol_applies)을 이 프로세스가 직접 쓴다
//             GET  /health                → ok        POST /shutdown → exits
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
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
// patrol_applies: 적재 원장은 이 프로세스가 /apply 에서 직접 쓴다. 세션이 SQL 로 완료 표시를 만들 수 있으면 영수증이 아니다.
const DENY_ANYWHERE = /\b(auth_tokens|sessions|contact_messages|api_budget|wake_log|site_meta|stats_daily|comment_decisions|patrol_applies|sqlite_master|sqlite_sequence|password_hash|google_sub|email|ATTACH|DETACH|PRAGMA|VACUUM|CREATE|DROP|ALTER|TRIGGER|INDEX|REINDEX|REPLACE|BEGIN|COMMIT|ROLLBACK|SAVEPOINT)\b/i;

// 읽을 수 있는 테이블 — **여기 없는 테이블은 전부 거부한다.**
// 예전에는 금지어 목록에 없으면 읽을 수 있었다. 그래서 스키마에 테이블이 하나 늘 때마다
// (dms, dm_images, room_messages, app_login_codes, account_deletions, safety_reports …)
// 순찰이 조용히 읽을 수 있게 됐다 — 사람끼리 주고받은 쪽지와 일회성 토큰까지.
// 새 테이블은 기본 거부가 맞다. 순찰이 정말 읽어야 하면 그때 이 목록에 이유와 함께 추가한다.
const READ_TABLES = new Set([
  'posts', 'comments', 'residents', 'users',      // users 는 아래에서 SELECT * 와 개인정보 컬럼이 따로 막힌다
  'follows', 'follow_events',                     // 관계 — 누가 누구를 따르는지는 사이트에 공개돼 있다
  'likes', 'resident_likes', 'poll_options', 'resident_poll_votes', // 반응 집계 (사람/AI 분리 보상의 입력)
  'reports',                                      // 신고 처리(The Management)
  'albums', 'album_images',                       // 앨범 — 커버 생성이 중복을 피하려고 읽는다
]);
/**
 * 이 문장이 '읽는' 테이블 전부 — FROM 뒤의 쉼표 목록(`FROM posts p, dms d`)과 JOIN 을 모두 센다.
 * 쓰기 대상(INSERT INTO x / UPDATE x / DELETE FROM x 의 x)은 여기 들어가지 않는다 — 그건 쓰기 규칙이 판정한다.
 * 그러나 INSERT 의 값 자리에 든 `(SELECT … FROM dms)` 는 읽기이므로 잡힌다.
 */
function readsIn(sk) {
  const body = sk.replace(/^DELETE FROM\s+[a-z_][a-z0-9_]*/i, 'DELETE'); // DELETE 의 대상만 떼고 나머지는 전부 읽기로 본다
  const out = [];
  for (const m of body.matchAll(/\b(?:FROM|JOIN)\s+([a-z_][a-z0-9_]*(?:\s+(?:AS\s+)?[a-z_][a-z0-9_]*)?(?:\s*,\s*[a-z_][a-z0-9_]*(?:\s+(?:AS\s+)?[a-z_][a-z0-9_]*)?)*)/gi)) {
    for (const part of m[1].split(',')) out.push(part.trim().split(/\s+/)[0].toLowerCase());
  }
  return out;
}
// 테이블 이름 자리에 문자열('dms')·괄호·점(main.dms)이 오면 이 파서가 못 읽는 참조다 — 전부 거부한다.
// skeleton 은 문자열을 '' 로 지우므로 `FROM 'dms'` 는 `FROM ''` 로 보인다.
const ODD_TABLE_REF = /\b(?:FROM|JOIN|INTO|UPDATE)\s*(?:''|\(|[a-z_][a-z0-9_]*\s*\.)/i;
const COMMA_AFTER_PAREN_SUBQUERY = /\bFROM\s*\([^)]*\)\s*,/i;
// `WITH recent AS (…) SELECT … FROM recent` 의 recent 는 테이블이 아니라 이 문장 안의 이름이다.
// CTE 안에서 진짜 테이블을 읽으면 그건 tablesIn 이 따로 잡는다.
const cteNames = (sk) => new Set([...sk.matchAll(/(?:\bWITH\b|,)\s*([a-z_][a-z0-9_]*)\s+AS\s*\(/gi)].map((m) => m[1].toLowerCase()));
// albums/album_images: 패널 쇼츠(여러 컷 만화)를 주민 글에 붙인다. 주인 컬럼은 resident_id 뿐(user_id 는
// INSERT_DENY_COLS)이라 사람 계정의 앨범을 지어낼 수는 없다.
// dms: 주민이 사람에게 답하는 쪽지만 (from_resident_id → to_user_id). 읽기는 여전히 거부 — 사람끼리의 쪽지가 같은 테이블이다.
const INSERT_TABLES = { posts: 1, comments: 1, poll_options: 1, resident_likes: 1, resident_poll_votes: 1, follows: 1, follow_events: 1, residents: 1, albums: 1, album_images: 1, dms: 1 };
const RESIDENT_ONLY_INSERT = new Set(['follows', 'follow_events']); // 사람의 팔로우·이력을 순찰이 지어내지 못하게
const INSERT_DENY_COLS = /\b(user_id|visitor_name|visitor_ip|password_hash|email|google_sub|tier)\b/i; // tier: no self-promotion to admin
const UPDATE_RULES = {
  posts: { cols: /^(pinned|og_image|series|album_id|resident_view_count|hidden|title|body|media_type|media_ref|topic|region|kind|created_at)$/, guard: 'user_id IS NULL', guardExempt: /^(hidden|resident_view_count)$/ },
  comments: { cols: /^(hidden|body)$/, guard: 'resident_id IS NOT NULL', guardExempt: /^hidden$/ },
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

/** 여는 따옴표 위치를 받아 닫는 따옴표 위치를 돌려준다 ('' 는 이스케이프) */
function skipLiteral(s, i) {
  for (let j = i + 1; j < s.length; j++) {
    if (s[j] !== "'") continue;
    if (s[j + 1] === "'") { j++; continue; }
    return j;
  }
  return s.length;
}

/** 깊이 0 의 쉼표로만 쪼갠다 — 값 안의 괄호·따옴표는 건너뛴다 */
function splitTopLevel(s) {
  const parts = [];
  let depth = 0, cur = '';
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch === "'") { const end = skipLiteral(s, i); cur += s.slice(i, end + 1); i = end; continue; }
    if (ch === '(') { depth++; cur += ch; continue; }
    if (ch === ')') { depth--; cur += ch; continue; }
    if (ch === ',' && depth === 0) { parts.push(cur); cur = ''; continue; }
    cur += ch;
  }
  parts.push(cur);
  return parts;
}

/** 깊이 0 에 있는 첫 WHERE 의 위치. 없으면 -1.
 *  서브쿼리 안의 WHERE 로 문장을 자르면 SET 절이 잘못 읽히고, 소유자 가드가 엉뚱한 테이블에 붙는다.
 *  (`UPDATE posts SET album_id=(SELECT id FROM albums WHERE …) WHERE id=7` 가 실제로 그랬다) */
function topLevelWhereIndex(s) {
  let depth = 0;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch === "'") { i = skipLiteral(s, i); continue; }
    if (ch === '(') { depth++; continue; }
    if (ch === ')') { depth--; continue; }
    if (depth === 0 && (ch === 'W' || ch === 'w') && /^where\b/i.test(s.slice(i, i + 6)) && (i === 0 || /\s/.test(s[i - 1]))) return i;
  }
  return -1;
}

/** "a = 1, b = 'x', c = c + 1" → [a, b, c].
 *  `col = expr` 로 읽히지 않는 조각이 하나라도 있으면 **null** — 모르는 구문은 통과시키지 않는다.
 *  예전에는 알아보지 못한 조각을 조용히 버렸다. 그래서 `SET hidden=0, (user_id, body)=(9,'x')` 처럼
 *  허용된 할당과 괄호형 다중 할당을 섞으면 보호 컬럼이 검사 없이 지나가고 소유자 가드도 빠졌다. */
function assignedColumns(setClause) {
  const cols = [];
  for (const part of splitTopLevel(setClause)) {
    const m = part.trim().match(/^([a-z_][a-z0-9_]*)\s*=(?!=)/i);
    if (!m) return null;
    cols.push(m[1].toLowerCase());
  }
  return cols;
}

/** 원문 INSERT 의 VALUES (…) 안 값들 — 깊이 0 쉼표로 나눈다. 못 찾으면 null */
function insertValues(stmt) {
  const open = stmt.indexOf('(', stmt.toUpperCase().indexOf(') VALUES'));
  const close = stmt.lastIndexOf(')');
  if (open < 0 || close <= open) return null;
  return splitTopLevel(stmt.slice(open + 1, close)).map((v) => v.trim());
}

// 자식 행은 부모의 주인을 따른다. 순찰이 사람의 앨범·사람의 글에 사진을 매달지 못하게,
// INSERT 를 `… SELECT 값들 WHERE EXISTS (부모가 주민 소유)` 로 바꿔 넣는다.
// 부모가 사람 것이면 행이 0개 들어가고, 문장은 실패하지 않는다.
const PARENT_GUARDS = {
  album_images: { col: 'album_id', owner: (v) => `SELECT 1 FROM albums WHERE id = ${v} AND resident_id IS NOT NULL AND user_id IS NULL` },
  albums: { col: 'origin_post_id', owner: (v) => `SELECT 1 FROM posts WHERE id = ${v} AND resident_id IS NOT NULL AND user_id IS NULL` },
};

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
  // 기본 거부: 서브쿼리·조인까지 포함해 이 문장이 '읽는' 모든 테이블이 허용 목록에 있어야 한다.
  // 쓰기 대상 테이블(INSERT INTO x / UPDATE x / DELETE FROM x)은 아래 쓰기 규칙이 따로 판정한다 —
  // dms 처럼 "쓸 수는 있지만 읽을 수는 없는" 테이블이 있다.
  if (ODD_TABLE_REF.test(sk) || COMMA_AFTER_PAREN_SUBQUERY.test(sk)) return { ok: false, reason: 'table reference shape not supported (string/paren/schema-qualified)' };
  const ctes = cteNames(sk);
  for (const t of readsIn(sk)) if (!READ_TABLES.has(t) && !ctes.has(t)) return { ok: false, reason: `table not readable: ${t}` };

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
    // 앨범은 주민 것만 만들 수 있다 — 주인 없는 앨범이 생기면 사람 글에 붙일 여지가 남는다
    if (table === 'albums' && !/\bresident_id\b/i.test(cols)) return { ok: false, reason: 'albums insert must set resident_id' };

    const names = splitTopLevel(cols).map((c) => c.trim().toLowerCase());
    const values = insertValues(stmt);
    if (!values || values.length !== names.length) return { ok: false, reason: `${table} insert column/value count mismatch` };

    // 쪽지는 "주민 → 사람" 한 방향, 실 열쇠는 그 둘로만 만들어진다. 사람 이름으로 보내거나 남의 실에 끼어드는 형태를 막는다.
    if (table === 'dms') {
      if (names.some((n) => !['thread', 'from_resident_id', 'to_user_id', 'body'].includes(n))) return { ok: false, reason: 'dms insert may only set thread, from_resident_id, to_user_id, body' };
      const rid = values[names.indexOf('from_resident_id')], uid = values[names.indexOf('to_user_id')], thread = values[names.indexOf('thread')];
      if (!/^\d+$/.test(rid ?? '') || !/^\d+$/.test(uid ?? '') || thread !== `'r${rid}|u${uid}'`) return { ok: false, reason: 'dms thread must be r<from_resident_id>|u<to_user_id>' };
      // 본문은 문자열 리터럴이어야 한다 — `(SELECT body FROM dms …)` 로 남의 쪽지를 복사해 넣는 길을 막는다
      const body = values[names.indexOf('body')];
      if (!body || !/^'(?:[^']|'')*'$/.test(body)) return { ok: false, reason: 'dms body must be a string literal' };
    }

    const guard = PARENT_GUARDS[table];
    if (guard) {
      const at = names.indexOf(guard.col);
      if (at > -1) {
        const parent = values[at];
        if (!/^\d+$/.test(parent)) return { ok: false, reason: `${table}.${guard.col} must be a literal id` };
        return { ok: true, sql: `INSERT INTO ${table} (${cols}) SELECT ${values.join(', ')} WHERE EXISTS (${guard.owner(parent)})`, guarded: true };
      }
    }
    return { ok: true, sql: stmt };
  }
  if (/^INSERT\b/i.test(sk)) {
    // 어떤 이유로든 위 형태를 벗어난 INSERT — UPSERT·다중행·INSERT..SELECT·후행 토큰 전부 여기서 걸린다
    return { ok: false, reason: 'insert must be a single VALUES row with nothing after it' };
  }

  m = sk.match(/^UPDATE ([a-z_]+) SET /i);
  if (m) {
    const table = m[1].toLowerCase(), rule = UPDATE_RULES[table];
    if (!rule) return { ok: false, reason: `update ${table}` };
    // SET/WHERE 는 깊이 0 에서 가른다 — 서브쿼리의 WHERE 로 자르면 두 절이 뒤섞인다
    const w = topLevelWhereIndex(sk);
    if (w < 0) return { ok: false, reason: 'update without WHERE' };
    const cols = assignedColumns(sk.slice(m[0].length, w));
    if (cols === null) return { ok: false, reason: `update ${table}: unparsed assignment` };
    if (!cols.length || cols.some((c) => !rule.cols.test(c))) return { ok: false, reason: `update ${table} column not allowed (${cols.join(',')})` };
    if (!rule.guard || cols.every((c) => rule.guardExempt?.test(c))) return { ok: true, sql: stmt };
    // 가드는 원문의 깊이 0 WHERE 에만 붙인다: UPDATE t SET ... WHERE (원래 조건) AND guard
    const trimmed = stmt.replace(/;\s*$/, '');
    const ow = topLevelWhereIndex(trimmed);
    if (ow < 0) return { ok: false, reason: 'update rewrite failed' };
    return { ok: true, sql: `${trimmed.slice(0, ow)}WHERE (${trimmed.slice(ow + 5).trim()}) AND ${rule.guard}`, guarded: true };
  }
  if (/^UPDATE\b/i.test(sk)) return { ok: false, reason: 'unsupported UPDATE shape' };

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
  const isApply = req.method === 'POST' && req.url === '/apply';
  if (!isApply && (req.method !== 'POST' || req.url !== '/query')) return send(404, { error: 'not found' });

  let body = '';
  for await (const chunk of req) { body += chunk; if (body.length > LIMITS.bodyBytes) return send(413, { error: 'body too large' }); }
  let sql, output;
  try { const j = JSON.parse(body); sql = String(j.sql || ''); output = typeof j.output === 'string' ? j.output : null; } catch { return send(400, { error: 'bad json' }); }
  if (isApply && output === null) return send(400, { error: '/apply needs output (the patrol-output.json text)' });

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

  // /apply: 적재 원장은 여기서만 쓴다 — 세션은 patrol_applies 에 SQL 로 닿을 수 없다(DENY_ANYWHERE).
  // run_id 는 출력 파일 내용의 해시. 같은 파일의 두 번째 시도는 PRIMARY KEY 에서 막히고,
  // completed_at 은 모든 문장이 실제로 들어간 뒤에만 찍힌다. 후처리 job 의 verify-apply 가 이 행을 본다.
  // 한계: 세션이 다른 SQL 을 같은 출력 파일과 함께 보낼 수는 있다 — 그 SQL 도 위 정책을 통과해야 하므로 권한은 넘지 못하지만,
  // "출력과 적재가 일치한다" 는 것까지 이 원장이 증명하지는 않는다.
  let runId = null;
  if (isApply) {
    runId = createHash('sha256').update(output).digest('hex').slice(0, 32);
    try {
      await upstream(`INSERT INTO patrol_applies (run_id, statements) VALUES ('${runId}', ${approved.length});`);
    } catch (e) {
      const prior = (await upstream(`SELECT statements, started_at, completed_at FROM patrol_applies WHERE run_id = '${runId}';`).catch(() => []))?.[0]?.results?.[0];
      if (!prior) { log(`LEDGER ERROR: ${e.message.slice(0, 200)}`); return send(502, { error: `ledger: ${e.message.slice(0, 300)}` }); }
      log(`REFUSED duplicate apply run=${runId} (${prior.completed_at ? 'completed' : 'incomplete'})`);
      return send(409, {
        error: prior.completed_at ? 'already_applied' : 'incomplete_previous_run',
        run_id: runId, statements: prior.statements, started_at: prior.started_at, completed_at: prior.completed_at,
      });
    }
  }

  try {
    const result = [];
    for (let i = 0; i < approved.length; i += LIMITS.upstreamChunk) {
      const chunk = approved.slice(i, i + LIMITS.upstreamChunk);
      result.push(...await upstream(chunk.map((s) => s.replace(/;\s*$/, '')).join(';\n') + ';'));
    }
    if (isApply) await upstream(`UPDATE patrol_applies SET completed_at = datetime('now') WHERE run_id = '${runId}';`);
    log(`ok ${approved.length} stmt${runId ? ` run=${runId}` : ''} (${approved.map((s) => s.slice(0, 6).toUpperCase().trim()).join(',').slice(0, 60)})`);
    send(200, runId ? { result, run_id: runId, statements: approved.length } : { result });
  } catch (e) {
    log(`UPSTREAM ERROR${runId ? ` run=${runId} (ledger left incomplete)` : ''}: ${e.message.slice(0, 300)}`);
    send(502, { error: e.message.slice(0, 500) });
  }
});

server.listen(PORT, '127.0.0.1', () => log(`d1-proxy listening on 127.0.0.1:${PORT} (upstream: ${UPSTREAM.replace(/database\/[^/]+/, 'database/…')})`));
