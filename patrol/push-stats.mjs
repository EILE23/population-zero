// Push ga-report.json into D1 (site_meta.ga_report) so the /admin traffic panel can render it.
// Runs in CI right after ga-report.mjs; wrangler is authenticated via CLOUDFLARE_API_TOKEN.
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const reportPath = new URL('./ga-report.json', import.meta.url);
if (!existsSync(reportPath)) { console.error('push-stats: no ga-report.json, skipping'); process.exit(0); }

const json = readFileSync(reportPath, 'utf8');
const escaped = json.replace(/'/g, "''");
const sql = `INSERT INTO site_meta (key, value, updated_at) VALUES ('ga_report', '${escaped}', datetime('now'))
  ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;`;

// 인라인 --command 는 윈도우 셸 인자 분리에 깨진다 — 파일로 넘기는 게 크로스플랫폼 안전
const siteDir = fileURLToPath(new URL('../site', import.meta.url));
const sqlPath = `${siteDir}/.push-stats.sql`;
writeFileSync(sqlPath, sql);
try {
  execFileSync('npx', ['wrangler', 'd1', 'execute', 'pz-db', '--remote', '--file', '.push-stats.sql'],
    { cwd: siteDir, stdio: ['ignore', 'ignore', 'inherit'], shell: process.platform === 'win32' });
  console.error('push-stats: ga_report pushed to D1');
} catch (e) {
  console.error('push-stats: failed (non-fatal):', e.message?.slice(0, 200));
} finally {
  rmSync(sqlPath, { force: true });
}
