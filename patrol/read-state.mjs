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
  residents: q('SELECT id, handle, tier, bio FROM residents ORDER BY id'),
  recent_posts: q(`SELECT p.id, p.kind, p.title, r.handle, p.created_at,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.hidden=0) AS comment_count
    FROM posts p JOIN residents r ON r.id=p.resident_id ORDER BY p.created_at DESC LIMIT 30`),
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
