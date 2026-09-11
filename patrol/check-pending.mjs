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

// human_pending: 미답 사람 댓글/글 — 항상 즉시 깨움.
// fresh_unreacted: 최근 3시간 안에 "실제로 발행된"(created_at이 현재를 지난) 주민 글 중
//   아직 주민 댓글도 좋아요도 하나도 없는 글 — 진짜 인과 사슬의 시작점. 쿨다운 적용해 깨움.
const SQL = `SELECT
  (SELECT COUNT(*) FROM comments c WHERE c.user_id IS NOT NULL AND c.hidden=0
     AND c.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.resident_id IS NOT NULL AND r.parent_id = c.id)) +
  (SELECT COUNT(*) FROM posts p WHERE p.user_id IS NOT NULL
     AND p.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL)) AS human_pending,
  (SELECT COUNT(*) FROM posts p WHERE p.resident_id IS NOT NULL
     AND p.created_at <= datetime('now') AND p.created_at > datetime('now','-3 hours')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL AND r.created_at <= datetime('now'))
     AND NOT EXISTS (SELECT 1 FROM resident_likes rl WHERE rl.post_id=p.id AND rl.created_at <= datetime('now'))) AS fresh_unreacted`;

let humanPending = 0, freshUnreacted = 0;
for (let attempt = 1; attempt <= 2; attempt++) { // Cloudflare API 일시 오류 1회 재시도
  try {
    const raw = execSync(`npx wrangler d1 execute pz-db --remote --command "${SQL.replace(/\s+/g, ' ')}" --json`,
      { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    const row = JSON.parse(raw.slice(raw.indexOf('[')))[0].results[0];
    humanPending = row.human_pending; freshUnreacted = row.fresh_unreacted;
    break;
  } catch (e) {
    if (attempt === 2) { console.log('d1 query failed twice, will retry next tick'); process.exit(0); }
  }
}
console.log(new Date().toISOString(), 'human_pending:', humanPending, 'fresh_unreacted:', freshUnreacted);

// 주민 글 반응용 깨움은 35분 쿨다운 (토큰 절약) — 사람 응답은 쿨다운 없이 즉시.
const COOLDOWN = new URL('./.wake-cooldown', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
let cooled = true;
try { cooled = Date.now() - Number(readFileSync(COOLDOWN, 'utf8')) > 35 * 60 * 1000; } catch { /* 없으면 통과 */ }
const pending = humanPending > 0 || (freshUnreacted > 0 && cooled) ? 1 : 0;

if (pending > 0) {
  if (freshUnreacted > 0) writeFileSync(COOLDOWN, String(Date.now()));
  const child = spawn('cmd', ['/c', 'C:\\works\\zavis\\ideas\\yarmeal\\patrol\\run-patrol.cmd', 'light'], {
    detached: true, stdio: 'ignore',
  });
  child.unref();
  writeFileSync(LOCK, JSON.stringify({ pid: child.pid, ts: Date.now() }));
  console.log('woke light patrol, pid', child.pid);
}
