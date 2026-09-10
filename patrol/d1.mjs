// D1 access for patrol scripts — one door, two backends.
//   PZ_D1_PROXY set (CI):   POST to the local d1-proxy (holds the token; enforces the allowlist)
//   otherwise (local dev):  wrangler CLI with your own login (--remote / --local as before)
//
// Library:  import { d1, rows } from './d1.mjs'
//   rows(sql)        → results of the first statement (array of objects)
//   d1(sql)          → [{results, meta}] for every statement (multi-statement OK)
// CLI:      node d1.mjs [--remote|--local] "SELECT ..."      → prints rows as JSON
//           node d1.mjs [--remote|--local] --file apply.sql
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SITE = fileURLToPath(new URL('../site', import.meta.url));
const PROXY = process.env.PZ_D1_PROXY || null;
export const remoteFlag = process.argv.includes('--local') ? '--local' : '--remote';

async function viaProxy(sql) {
  const res = await fetch(`${PROXY}/query`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ sql }) });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`d1-proxy ${res.status}: ${json.error || 'error'}${json.statement ? ` — ${json.statement}` : ''}`);
  return json.result;
}

// wrangler's JS entry called directly (no npx/.cmd shell) — arguments pass verbatim, so SQL needs no shell quoting
const WRANGLER = path.join(SITE, 'node_modules', 'wrangler', 'bin', 'wrangler.js');
const isSingle = (sql) => !/;\s*\S/.test(sql.replace(/'(?:[^']|'')*'/g, "''")); // one statement (a trailing ; is fine)

function viaWrangler(sql, flag) {
  const base = [WRANGLER, 'd1', 'execute', 'pz-db', flag, '--json'];
  const run = (args) => {
    const raw = execFileSync(process.execPath, [...base, ...args], { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return JSON.parse(raw.slice(raw.indexOf('[')));
  };
  // --command returns rows; --file (multi-statement batches) returns only a summary — reads always go through --command
  if (isSingle(sql)) return run(['--command', sql.replace(/;\s*$/, '')]);
  const tmp = path.join(SITE, `.d1-${process.pid}-${Date.now().toString(36)}.sql`);
  writeFileSync(tmp, sql);
  try { return run(['--file', path.basename(tmp)]); } finally { rmSync(tmp, { force: true }); }
}

export async function d1(sql, flag = remoteFlag) {
  return PROXY ? viaProxy(sql) : viaWrangler(sql, flag);
}
export async function rows(sql, flag = remoteFlag) {
  const r = await d1(sql, flag);
  return r?.[0]?.results ?? [];
}

// ── CLI ────────────────────────────────────────────────────────────────────────
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const args = process.argv.slice(2).filter((a) => a !== '--remote' && a !== '--local');
  const fi = args.indexOf('--file');
  const sql = fi > -1 ? readFileSync(args[fi + 1], 'utf8') : args.join(' ');
  if (!sql.trim()) { console.error('usage: node d1.mjs [--remote|--local] "SQL" | --file x.sql'); process.exit(1); }
  try {
    const r = await d1(sql);
    console.log(JSON.stringify(r.length === 1 ? r[0].results : r.map((x) => x.results), null, 2));
  } catch (e) { console.error(e.message); process.exit(1); }
}
