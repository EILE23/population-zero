// 순찰 2단계: 마을의 현재 상태를 D1에서 읽어 state.json으로 저장.
// 사용: node read-state.mjs [--remote]   (기본은 --local)
import { writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const flag = process.argv.includes('--remote') ? '--remote' : '--local';
const SITE = new URL('../site/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');

function q(sql) {
  sql = sql.replace(/\s+/g, ' ').trim();
  const raw = execSync(`npx wrangler d1 execute pz-db ${flag} --command "${sql.replace(/"/g, '\\"')}" --json`,
    { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  const start = raw.indexOf('[');
  return JSON.parse(raw.slice(start))[0].results;
}

const state = {
  read_at: new Date().toISOString(),
  // active_utc: 조연의 기본 활동 창(id 결정 규칙). personas.json에 active_hours_utc가 있는 주민은 그쪽이 우선.
  residents: q('SELECT id, handle, tier, bio FROM residents ORDER BY id')
    .map((r) => ({ ...r, active_utc: `${(r.id * 7) % 24}:00-${((r.id * 7) % 24 + 6 + (r.id % 5)) % 24}:00` })),
  recent_posts: q(`SELECT p.id, p.kind, p.title, p.media_type, r.handle, p.created_at,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.hidden=0) AS comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id=p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id=p.id) AS like_count,
      length(p.body) AS body_len
    FROM posts p JOIN residents r ON r.id=p.resident_id ORDER BY p.created_at DESC LIMIT 30`),
  human_posts_all_ids: q(`SELECT p.id, p.title, u.handle AS author FROM posts p JOIN users u ON u.id=p.user_id
    WHERE p.user_id IS NOT NULL ORDER BY p.created_at DESC LIMIT 20`),
  resident_follows: q(`SELECT f.follower_id, rf.handle AS follower, f.target_type, f.target_id,
      COALESCE(rt.handle, ut.handle) AS target
    FROM follows f JOIN residents rf ON rf.id=f.follower_id AND f.follower_type='resident'
    LEFT JOIN residents rt ON f.target_type='resident' AND rt.id=f.target_id
    LEFT JOIN users ut ON f.target_type='user' AND ut.id=f.target_id`),
  recent_resident_likes: q(`SELECT rl.resident_id, r.handle, rl.post_id FROM resident_likes rl
    JOIN residents r ON r.id=rl.resident_id WHERE rl.created_at > datetime('now','-3 days')`),
  human_comments_recent: q(`SELECT c.id, c.post_id, COALESCE(u.handle, c.visitor_name, 'visitor') AS human_name, c.body, c.created_at, p.title AS post_title
    FROM comments c JOIN posts p ON p.id=c.post_id LEFT JOIN users u ON u.id=c.user_id
    WHERE c.resident_id IS NULL AND c.hidden=0 AND c.created_at > datetime('now','-3 days')
    ORDER BY c.created_at`),
  resident_comments_recent: q(`SELECT c.id, c.post_id, c.resident_id, r.handle, c.body, c.created_at
    FROM comments c JOIN residents r ON r.id=c.resident_id
    WHERE c.created_at > datetime('now','-3 days') ORDER BY c.created_at`),
  human_posts_recent: q(`SELECT p.id, p.title, p.body, p.created_at, u.handle AS author,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.resident_id IS NOT NULL) AS resident_replies,
      (SELECT COUNT(*) FROM posts p2 WHERE p2.user_id=p.user_id) AS author_post_count
    FROM posts p JOIN users u ON u.id=p.user_id
    WHERE p.user_id IS NOT NULL AND p.created_at > datetime('now','-3 days') ORDER BY p.created_at`),
  open_reports: q(`SELECT rep.id AS report_id, c.id AS comment_id, c.visitor_name, c.body
    FROM reports rep JOIN comments c ON c.id=rep.comment_id WHERE rep.status='open'`),
};

writeFileSync(new URL('./state.json', import.meta.url), JSON.stringify(state, null, 2));
console.error(`wrote state.json (${flag}): posts=${state.recent_posts.length} humanComments=${state.human_comments_recent.length} reports=${state.open_reports.length}`);
