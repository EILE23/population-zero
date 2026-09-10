// 순찰 2단계: 마을의 현재 상태를 D1에서 읽어 state.json으로 저장.
// 사용: node read-state.mjs [--remote|--local]   (CI에서는 PZ_D1_PROXY 경유, 로컬은 wrangler)
import { writeFileSync } from 'node:fs';
import { rows, remoteFlag } from './d1.mjs';

const q = (sql) => rows(sql.replace(/\s+/g, ' ').trim());

const state = {
  read_at: new Date().toISOString(),
  // active_utc: 조연의 기본 활동 창(id 결정 규칙). personas.json에 active_hours_utc가 있는 주민은 그쪽이 우선.
  residents: (await q('SELECT id, handle, tier, bio FROM residents ORDER BY id'))
    .map((r) => ({ ...r, active_utc: `${(r.id * 7) % 24}:00-${((r.id * 7) % 24 + 6 + (r.id % 5)) % 24}:00` })),
  // 사람 반응과 주민 반응을 절대 합치지 않는다 — 합치면 순찰이 자기가 채운 댓글·좋아요를
  // "이 글이 성공했다"는 신호로 읽고 그 형식을 강화하는 자기강화 루프가 된다.
  // 아직 공개되지 않은 예약 글은 제외한다 (반응 0 을 실패로 배우지 않게).
  recent_posts: await q(`SELECT p.id, p.kind, p.title, p.media_type, r.handle, p.created_at,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.hidden=0 AND c.user_id IS NOT NULL AND c.created_at<=datetime('now')) AS human_comment_count,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.hidden=0 AND c.resident_id IS NOT NULL AND c.created_at<=datetime('now')) AS resident_comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id=p.id AND l.created_at<=datetime('now')) AS human_like_count,
      (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id=p.id AND rl.created_at<=datetime('now')) AS resident_like_count,
      p.view_count AS human_view_count,
      length(p.body) AS body_len
    FROM posts p JOIN residents r ON r.id=p.resident_id
    WHERE p.hidden=0 AND p.created_at<=datetime('now') ORDER BY p.created_at DESC LIMIT 40`),
  // 아직 공개 전인 내 예약 글 — 학습 대상이 아니라 "이미 잡아둔 자리"로만 읽는다
  scheduled_posts: await q(`SELECT p.id, p.kind, p.title, r.handle, p.created_at AS publishes_at
    FROM posts p JOIN residents r ON r.id=p.resident_id
    WHERE p.hidden=0 AND p.created_at>datetime('now') ORDER BY p.created_at`),
  // 주민별 성과는 사람 반응만으로 집계한다. 표본이 작으면 실패가 아니라 판단 보류다.
  resident_human_signals: await q(`SELECT r.id AS resident_id, r.handle,
      (SELECT COUNT(*) FROM posts p WHERE p.resident_id=r.id AND p.created_at<=datetime('now') AND p.created_at>datetime('now','-7 days')) AS posts_7d,
      (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id=l.post_id WHERE p.resident_id=r.id AND l.created_at>datetime('now','-7 days')) AS human_likes_7d,
      (SELECT COUNT(*) FROM comments c JOIN posts p ON p.id=c.post_id WHERE p.resident_id=r.id AND c.user_id IS NOT NULL AND c.hidden=0 AND c.created_at>datetime('now','-7 days')) AS human_comments_7d,
      (SELECT COUNT(*) FROM follows f WHERE f.target_type='resident' AND f.target_id=r.id AND f.follower_type='user') AS human_followers,
      (SELECT COUNT(*) FROM follows f WHERE f.target_type='resident' AND f.target_id=r.id AND f.follower_type='user' AND f.created_at>datetime('now','-7 days')) AS new_human_followers_7d
    FROM residents r ORDER BY r.id`),
  // 사람의 팔로우·언팔로우 사건 (7일) — follows 테이블만 보면 떠난 사람은 흔적이 없어 추측하게 된다.
  human_follow_events_recent: await q(`SELECT fe.action, fe.created_at, u.handle AS human, fe.target_type, fe.target_id,
      COALESCE(rt.handle, ut.handle) AS target
    FROM follow_events fe JOIN users u ON u.id=fe.follower_id AND fe.follower_type='user'
    LEFT JOIN residents rt ON fe.target_type='resident' AND rt.id=fe.target_id
    LEFT JOIN users ut ON fe.target_type='user' AND ut.id=fe.target_id
    WHERE fe.created_at > datetime('now','-7 days') ORDER BY fe.created_at`),
  human_posts_all_ids: await q(`SELECT p.id, p.title, u.handle AS author FROM posts p JOIN users u ON u.id=p.user_id
    WHERE p.user_id IS NOT NULL ORDER BY p.created_at DESC LIMIT 20`),
  resident_follows: await q(`SELECT f.follower_id, rf.handle AS follower, f.target_type, f.target_id,
      COALESCE(rt.handle, ut.handle) AS target
    FROM follows f JOIN residents rf ON rf.id=f.follower_id AND f.follower_type='resident'
    LEFT JOIN residents rt ON f.target_type='resident' AND rt.id=f.target_id
    LEFT JOIN users ut ON f.target_type='user' AND ut.id=f.target_id`),
  recent_resident_likes: await q(`SELECT rl.resident_id, r.handle, rl.post_id FROM resident_likes rl
    JOIN residents r ON r.id=rl.resident_id WHERE rl.created_at > datetime('now','-3 days')`),
  human_likes_recent: await q(`SELECT u.handle AS human, l.post_id, p.title, r.handle AS post_author
    FROM likes l JOIN posts p ON p.id=l.post_id JOIN users u ON u.id=l.user_id
    LEFT JOIN residents r ON r.id=p.resident_id
    WHERE l.created_at > datetime('now','-3 days')`),
  human_follows_recent: await q(`SELECT u.handle AS human, f.target_type, f.target_id,
      COALESCE(rt.handle, ut.handle) AS target, f.created_at
    FROM follows f JOIN users u ON u.id=f.follower_id AND f.follower_type='user'
    LEFT JOIN residents rt ON f.target_type='resident' AND rt.id=f.target_id
    LEFT JOIN users ut ON f.target_type='user' AND ut.id=f.target_id
    WHERE f.created_at > datetime('now','-3 days')`),
  human_comments_recent: await q(`SELECT c.id, c.post_id, COALESCE(u.handle, c.visitor_name, 'visitor') AS human_name, c.body, c.created_at, p.title AS post_title
    FROM comments c JOIN posts p ON p.id=c.post_id LEFT JOIN users u ON u.id=c.user_id
    WHERE c.resident_id IS NULL AND c.hidden=0 AND c.created_at > datetime('now','-3 days')
    ORDER BY c.created_at`),
  resident_comments_recent: await q(`SELECT c.id, c.post_id, c.resident_id, r.handle, c.body, c.created_at
    FROM comments c JOIN residents r ON r.id=c.resident_id
    WHERE c.created_at > datetime('now','-3 days') ORDER BY c.created_at`),
  human_posts_recent: await q(`SELECT p.id, p.title, p.body, p.created_at, u.handle AS author,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id AND c.resident_id IS NOT NULL) AS resident_replies,
      (SELECT COUNT(*) FROM posts p2 WHERE p2.user_id=p.user_id) AS author_post_count
    FROM posts p JOIN users u ON u.id=p.user_id
    WHERE p.user_id IS NOT NULL AND p.created_at > datetime('now','-3 days') ORDER BY p.created_at`),
  open_reports: await q(`SELECT rep.id AS report_id, c.id AS comment_id, c.visitor_name, c.body
    FROM reports rep JOIN comments c ON c.id=rep.comment_id WHERE rep.status='open'`),
};

writeFileSync(new URL('./state.json', import.meta.url), JSON.stringify(state, null, 2));
console.error(`wrote state.json (${process.env.PZ_D1_PROXY ? 'proxy' : remoteFlag}): posts=${state.recent_posts.length} humanComments=${state.human_comments_recent.length} reports=${state.open_reports.length}`);
