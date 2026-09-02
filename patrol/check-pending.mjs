// 10분마다 실행되는 초경량 감시자 (Claude 아님 — 토큰 0).
// 미응답 사람 댓글/글이 있을 때만 라이트 순찰(run-patrol.cmd light)을 깨운다.
// 자가 복구: 잠금에 순찰 PID를 기록하고, 그 프로세스가 죽어 있으면 잠금을 걷어내고 다시 깨운다.
import { execSync, spawn } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const SITE = 'C:/works/zavis/ideas/yarmeal/site';
const LOCK = new URL('./.patrol-lock', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const LOCK_TTL_MS = 45 * 60 * 1000; // 어떤 경우든 45분 넘은 잠금은 무효

function pidAlive(pid) {
  if (!pid) return false;
  try {
    const out = execSync(`tasklist /FI "PID eq ${pid}" /NH`, { encoding: 'utf8' });
    return out.includes(String(pid));
  } catch { return false; }
}

// 잠금 검사: 살아있는 순찰이 있으면 물러난다. 죽은 순찰의 잠금은 걷어낸다.
if (existsSync(LOCK)) {
  let stale = true;
  try {
    const { pid, ts } = JSON.parse(readFileSync(LOCK, 'utf8'));
    const age = Date.now() - Number(ts || 0);
    if (age < LOCK_TTL_MS && pidAlive(pid)) stale = false;
  } catch { /* 구형/깨진 잠금 → stale */ }
  if (!stale) { console.log('patrol alive, skip'); process.exit(0); }
  console.log('stale lock from a dead patrol — clearing and re-waking');
}

const SQL = `SELECT
  (SELECT COUNT(*) FROM comments c WHERE c.user_id IS NOT NULL AND c.hidden=0
     AND c.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=c.post_id AND r.resident_id IS NOT NULL AND r.created_at > c.created_at)) +
  (SELECT COUNT(*) FROM posts p WHERE p.user_id IS NOT NULL
     AND p.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL)) AS pending`;

let pending = 0;
for (let attempt = 1; attempt <= 2; attempt++) { // Cloudflare API 일시 오류 1회 재시도
  try {
    const raw = execSync(`npx wrangler d1 execute pz-db --remote --command "${SQL.replace(/\s+/g, ' ')}" --json`,
      { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    pending = JSON.parse(raw.slice(raw.indexOf('[')))[0].results[0].pending;
    break;
  } catch (e) {
    if (attempt === 2) { console.log('d1 query failed twice, will retry next tick'); process.exit(0); }
  }
}
console.log(new Date().toISOString(), 'pending:', pending);

if (pending > 0) {
  const child = spawn('cmd', ['/c', 'C:\\works\\zavis\\ideas\\yarmeal\\patrol\\run-patrol.cmd', 'light'], {
    detached: true, stdio: 'ignore',
  });
  child.unref();
  writeFileSync(LOCK, JSON.stringify({ pid: child.pid, ts: Date.now() }));
  console.log('woke light patrol, pid', child.pid);
}
