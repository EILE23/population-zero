// 매일 건강검진 — "돌았다" 가 아니라 "제때였나 · 답했나 · 적재됐나" 를 센다. 결과는 site_meta.health → /admin 상단.
// 오늘까지의 사고는 전부 조용히 실패하는 종류였다: 즉답 레인이 한 번도 답한 적 없음, 세션이 35분에 잘림, 크론 누락.
// 실행: CI post job 의 record-run 뒤 (wrangler 토큰), 로컬은 node health.mjs
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { rows } from './d1.mjs';

const here = (n) => new URL(n, import.meta.url);
const q = (sql) => rows(sql.replace(/\s+/g, ' ').trim());
const now = Date.now();
const H = 3600e3;

// ── 운영 기록(run-log) 24시간 ──
const runs = existsSync(here('./run-log.jsonl'))
  ? readFileSync(here('./run-log.jsonl'), 'utf8').trim().split('\n').map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter((r) => r && now - Date.parse(r.at) < 24 * H)
  : [];
const fulls = runs.filter((r) => r.mode === 'full');
const lastFullAgeH = fulls.length ? (now - Date.parse(fulls[fulls.length - 1].at)) / H : Infinity;
const failed = runs.filter((r) => r.ok === false);
const tokens = runs.reduce((s, r) => s + (r.gateway?.in ?? 0) + (r.gateway?.out ?? 0), 0);
const posts = runs.reduce((s, r) => s + (r.posts ?? 0), 0);
const writerPieces = runs.flatMap((r) => r.writer?.posts ?? []);
const writerFailed = runs.filter((r) => r.writer && r.writer.ok === false).length;
const d1Refused = runs.reduce((s, r) => s + (r.d1?.refused ?? 0), 0);
const skippedIdle = runs.filter((r) => r.session === 'skipped-idle').length;

// ── 즉답 레인 ──
let lane = { comments_replied: 0, comments_skipped: 0, dms_replied: 0, dms_skipped: 0, api_calls_today: 0, pending_comments: 0, pending_dms: 0 };
try {
  const [c] = await q(`SELECT SUM(decision='replied') AS replied, SUM(decision='skipped') AS skipped FROM comment_decisions WHERE ts > datetime('now','-1 day')`);
  const [d] = await q(`SELECT SUM(decision='replied') AS replied, SUM(decision='skipped') AS skipped FROM dm_decisions WHERE ts > datetime('now','-1 day')`);
  const [b] = await q(`SELECT COALESCE(MAX(calls),0) AS calls FROM api_budget WHERE day = date('now')`);
  const [p] = await q(`SELECT
    (SELECT COUNT(*) FROM comments c WHERE c.user_id IS NOT NULL AND c.hidden=0 AND c.created_at > datetime('now','-1 day') AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.resident_id IS NOT NULL AND r.parent_id=c.id)) AS pc,
    (SELECT COUNT(*) FROM dms d WHERE d.to_resident_id IS NOT NULL AND d.from_user_id IS NOT NULL AND d.created_at > datetime('now','-1 day') AND d.id=(SELECT MAX(d2.id) FROM dms d2 WHERE d2.thread=d.thread)) AS pd`);
  lane = { comments_replied: c?.replied ?? 0, comments_skipped: c?.skipped ?? 0, dms_replied: d?.replied ?? 0, dms_skipped: d?.skipped ?? 0, api_calls_today: b?.calls ?? 0, pending_comments: p?.pc ?? 0, pending_dms: p?.pd ?? 0 };
} catch (e) { console.error('health: lane query failed', e.message?.slice(0, 120)); }

// ── 판정 ──
const problems = [];
if (lastFullAgeH > 7) problems.push(`no full patrol for ${lastFullAgeH === Infinity ? '24h+' : lastFullAgeH.toFixed(1) + 'h'} (schedule is every 6h; GitHub cron may be skipping)`);
if (failed.length) problems.push(`${failed.length} failed/cancelled run(s) in 24h`);
if (lane.comments_skipped + lane.dms_skipped >= 3 && lane.comments_replied + lane.dms_replied === 0) problems.push(`instant lane skipped ${lane.comments_skipped + lane.dms_skipped} and replied 0 — model returning empty?`);
if (lane.pending_dms > 0 && lane.dms_replied + lane.dms_skipped === 0) problems.push(`${lane.pending_dms} DM(s) waiting with no watcher decision — watcher not running?`);
if (writerFailed) problems.push(`writer job refused ${writerFailed} time(s)`);
if (d1Refused > 0) problems.push(`D1 proxy refused ${d1Refused} statement(s) — a gate or an injection attempt`);
const ranSessions = runs.filter((r) => r.session === 'ran').length;
const perSession = ranSessions ? tokens / ranSessions : 0;
if (perSession > 400_000) problems.push(`avg ${Math.round(perSession / 1000)}k tokens (in+out) per session — reading too much; see run-log reads.top`);

const health = {
  at: new Date().toISOString(), ok: problems.length === 0, problems,
  runs_24h: runs.length, full_runs_24h: fulls.length, last_full_age_h: lastFullAgeH === Infinity ? null : +lastFullAgeH.toFixed(1),
  failed_24h: failed.length, skipped_idle_24h: skippedIdle, posts_24h: posts, tokens_24h: tokens,
  writer_pieces_24h: writerPieces.map((p) => p.title), lane,
};
writeFileSync(here('./health.json'), JSON.stringify(health, null, 2));
console.error(`health: ${health.ok ? 'OK' : 'PROBLEMS'} ${problems.join(' | ')}`);

// site_meta.health — /admin 이 읽는다 (push-stats 와 같은 방식: 파일로 넘겨 셸 인자 문제를 피한다)
if (!process.argv.includes('--no-push')) {
  const escaped = JSON.stringify(health).replace(/'/g, "''");
  const siteDir = fileURLToPath(here('../site/'));
  const sqlPath = `${siteDir}.health.sql`;
  writeFileSync(sqlPath, `INSERT INTO site_meta (key, value, updated_at) VALUES ('health', '${escaped}', datetime('now')) ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;`);
  try {
    execFileSync('npx', ['wrangler', 'd1', 'execute', 'pz-db', '--remote', '--file', '.health.sql'], { cwd: siteDir, stdio: ['ignore', 'ignore', 'inherit'], shell: process.platform === 'win32' });
    console.error('health: pushed to site_meta');
  } catch (e) { console.error('health: push failed (non-fatal):', e.message?.slice(0, 160)); } finally { rmSync(sqlPath, { force: true }); }
}
