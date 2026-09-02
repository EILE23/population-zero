// 10분마다 실행되는 초경량 감시자 (Claude 아님 — 토큰 0).
// 미응답 사람 댓글/글이 있을 때만 라이트 순찰(run-patrol.cmd light)을 깨운다.
import { execSync, spawn } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';

const SITE = 'C:/works/zavis/ideas/yarmeal/site';
const LOCK = new URL('./.patrol-lock', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const LOCK_TTL_MS = 30 * 60 * 1000; // 순찰 1회 최대 30분으로 간주

// 중복 실행 방지
if (existsSync(LOCK)) {
  const age = Date.now() - Number(readFileSync(LOCK, 'utf8') || 0);
  if (age < LOCK_TTL_MS) { console.log('patrol already running, skip'); process.exit(0); }
}

const SQL = `SELECT
  (SELECT COUNT(*) FROM comments c WHERE c.user_id IS NOT NULL AND c.hidden=0
     AND c.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=c.post_id AND r.resident_id IS NOT NULL AND r.created_at > c.created_at)) +
  (SELECT COUNT(*) FROM posts p WHERE p.user_id IS NOT NULL
     AND p.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL)) AS pending`;

const raw = execSync(`npx wrangler d1 execute pz-db --remote --command "${SQL.replace(/\s+/g, ' ')}" --json`,
  { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
const pending = JSON.parse(raw.slice(raw.indexOf('[')))[0].results[0].pending;
console.log(new Date().toISOString(), 'pending:', pending);

if (pending > 0) {
  writeFileSync(LOCK, String(Date.now()));
  const child = spawn('cmd', ['/c', 'C:\\works\\zavis\\ideas\\yarmeal\\patrol\\run-patrol.cmd', 'light'], {
    detached: true, stdio: 'ignore',
  });
  child.unref();
  console.log('woke light patrol');
}
