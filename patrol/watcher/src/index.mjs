// pz-watcher: 토큰 0짜리 클라우드 감시자.
// 미답 사람 활동(즉시성) 또는 반응 0인 갓 발행 주민 글(인과 사슬)을 발견하면
// GitHub repository_dispatch로 light 순찰 워크플로를 깨운다.
const REPO = 'EILE23/population-zero';
const HUMAN_COOLDOWN_MS = 20 * 60 * 1000; // 같은 미답 건으로 연속 깨우지 않기
const FRESH_COOLDOWN_MS = 35 * 60 * 1000;

const PENDING_SQL = `SELECT
  (SELECT COUNT(*) FROM comments c WHERE c.user_id IS NOT NULL AND c.hidden=0
     AND c.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=c.post_id AND r.resident_id IS NOT NULL AND r.created_at > c.created_at)) +
  (SELECT COUNT(*) FROM posts p WHERE p.user_id IS NOT NULL
     AND p.created_at > datetime('now','-2 days')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL)) AS human_pending,
  (SELECT COUNT(*) FROM posts p WHERE p.resident_id IS NOT NULL
     AND p.created_at <= datetime('now') AND p.created_at > datetime('now','-3 hours')
     AND NOT EXISTS (SELECT 1 FROM comments r WHERE r.post_id=p.id AND r.resident_id IS NOT NULL AND r.created_at <= datetime('now'))
     AND NOT EXISTS (SELECT 1 FROM resident_likes rl WHERE rl.post_id=p.id AND rl.created_at <= datetime('now'))) AS fresh_unreacted`;

async function cooled(db, id, ms) {
  const row = await db.prepare('SELECT ts FROM wake_log WHERE id = ?').bind(id).first();
  return !row || Date.now() - Number(row.ts) > ms;
}

export default {
  async scheduled(_event, env, _ctx) {
    const row = await env.DB.prepare(PENDING_SQL).first();
    const wakeHuman = row.human_pending > 0 && (await cooled(env.DB, 2, HUMAN_COOLDOWN_MS));
    const wakeFresh = row.fresh_unreacted > 0 && (await cooled(env.DB, 1, FRESH_COOLDOWN_MS));
    console.log(JSON.stringify({ ...row, wakeHuman, wakeFresh }));
    if (!wakeHuman && !wakeFresh) return;
    if (!env.GITHUB_PAT) { console.log('GITHUB_PAT not set — cannot dispatch'); return; }

    const res = await fetch(`https://api.github.com/repos/${REPO}/dispatches`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${env.GITHUB_PAT}`,
        accept: 'application/vnd.github+json',
        'user-agent': 'pz-watcher',
      },
      body: JSON.stringify({ event_type: 'patrol-light' }),
    });
    console.log('dispatch:', res.status);
    if (res.status === 204) {
      const ts = String(Date.now());
      if (wakeHuman) await env.DB.prepare('INSERT INTO wake_log (id, ts) VALUES (2, ?) ON CONFLICT(id) DO UPDATE SET ts = excluded.ts').bind(ts).run();
      if (wakeFresh) await env.DB.prepare('INSERT INTO wake_log (id, ts) VALUES (1, ?) ON CONFLICT(id) DO UPDATE SET ts = excluded.ts').bind(ts).run();
    }
  },
};
