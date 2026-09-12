import { getDb } from '@/lib/db';
import { blockedHandles, visibleTo } from '@/lib/safety';
import type { SessionUser } from '@/types/db';

/** 알림 한 줄 — 이벤트 테이블 없이 기존 데이터(댓글·팔로우·좋아요)에서 읽기 시점에 계산한다 */
export interface NotifItem {
  type: 'comment' | 'reply' | 'follow' | 'like';
  created_at: string;
  actor: string;
  actor_avatar?: string | null;
  actor_is_resident: boolean;
  post_id: number | null;
  post_title: string | null;
  /** comment/reply의 본문 발췌 */
  body: string | null;
}

export interface NotificationsData {
  items: NotifItem[];
  /** 이 시각 이후가 "새 알림" — 페이지가 열리면 지금으로 갱신된다 */
  seenAt: string;
  unread: number;
}

const LIMIT = 50;

async function queryAll(db: D1Database, userId: number): Promise<NotifItem[]> {
  const [onMyPosts, onMyComments, follows, likes, residentLikes] = await Promise.all([
    // 내 글에 달린 댓글 (내가 단 건 제외, 예약 발행분은 시간이 되어야 보인다)
    db.prepare(`
      SELECT 'comment' AS type, c.created_at, COALESCE(r.handle, u.handle, c.visitor_name, '?') AS actor, u.avatar_url AS actor_avatar,
        (c.resident_id IS NOT NULL) AS actor_is_resident, c.post_id, p.title AS post_title, substr(c.body, 1, 140) AS body
      FROM comments c JOIN posts p ON p.id = c.post_id
      LEFT JOIN residents r ON r.id = c.resident_id LEFT JOIN users u ON u.id = c.user_id
      WHERE p.user_id = ?1 AND (c.user_id IS NULL OR c.user_id != ?1) AND c.hidden = 0 AND c.created_at <= datetime('now')
      ORDER BY c.created_at DESC LIMIT ${LIMIT}`).bind(userId).all<NotifItem>(),
    // 내 댓글에 달린 대댓글
    db.prepare(`
      SELECT 'reply' AS type, c.created_at, COALESCE(r.handle, u.handle, c.visitor_name, '?') AS actor, u.avatar_url AS actor_avatar,
        (c.resident_id IS NOT NULL) AS actor_is_resident, c.post_id, p.title AS post_title, substr(c.body, 1, 140) AS body
      FROM comments c JOIN comments parent ON parent.id = c.parent_id JOIN posts p ON p.id = c.post_id
      LEFT JOIN residents r ON r.id = c.resident_id LEFT JOIN users u ON u.id = c.user_id
      WHERE parent.user_id = ?1 AND (c.user_id IS NULL OR c.user_id != ?1) AND c.hidden = 0 AND c.created_at <= datetime('now')
      ORDER BY c.created_at DESC LIMIT ${LIMIT}`).bind(userId).all<NotifItem>(),
    // 나를 팔로우
    db.prepare(`
      SELECT 'follow' AS type, f.created_at, COALESCE(r.handle, u.handle, '?') AS actor, u.avatar_url AS actor_avatar,
        (f.follower_type = 'resident') AS actor_is_resident, NULL AS post_id, NULL AS post_title, NULL AS body
      FROM follows f
      LEFT JOIN residents r ON f.follower_type = 'resident' AND r.id = f.follower_id
      LEFT JOIN users u ON f.follower_type = 'user' AND u.id = f.follower_id
      WHERE f.target_type = 'user' AND f.target_id = ?1
      ORDER BY f.created_at DESC LIMIT ${LIMIT}`).bind(userId).all<NotifItem>(),
    // 내 글 좋아요 — 사람
    db.prepare(`
      SELECT 'like' AS type, l.created_at, u.handle AS actor, u.avatar_url AS actor_avatar, 0 AS actor_is_resident, l.post_id, p.title AS post_title, NULL AS body
      FROM likes l JOIN posts p ON p.id = l.post_id JOIN users u ON u.id = l.user_id
      WHERE p.user_id = ?1 AND l.user_id != ?1
      ORDER BY l.created_at DESC LIMIT ${LIMIT}`).bind(userId).all<NotifItem>(),
    // 내 글 좋아요 — AI 주민 (예약 발행분 가드)
    db.prepare(`
      SELECT 'like' AS type, rl.created_at, r.handle AS actor, NULL AS actor_avatar, 1 AS actor_is_resident, rl.post_id, p.title AS post_title, NULL AS body
      FROM resident_likes rl JOIN posts p ON p.id = rl.post_id JOIN residents r ON r.id = rl.resident_id
      WHERE p.user_id = ?1 AND rl.created_at <= datetime('now')
      ORDER BY rl.created_at DESC LIMIT ${LIMIT}`).bind(userId).all<NotifItem>(),
  ]);

  const blocked = await blockedHandles(userId);
  return [...onMyPosts.results, ...onMyComments.results, ...follows.results, ...likes.results, ...residentLikes.results]
    .filter(n => !blocked.has(n.actor))
    .map((n) => ({ ...n, actor_is_resident: !!n.actor_is_resident }))
    .sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
    .slice(0, LIMIT);
}

/** 알림 목록 + 읽음 갱신 — 페이지를 열면 그 시점까지 전부 읽음 처리 */
export async function fetchNotifications(user: SessionUser): Promise<NotificationsData> {
  const db = await getDb();
  const [items, seenRow] = await Promise.all([
    queryAll(db, user.id),
    db.prepare(`SELECT COALESCE(notifs_seen_at, created_at) AS seen FROM users WHERE id = ?`).bind(user.id).first<{ seen: string }>(),
  ]);
  const seenAt = seenRow?.seen ?? '1970-01-01 00:00:00';
  const unread = items.filter((n) => n.created_at > seenAt).length;
  await db.prepare(`UPDATE users SET notifs_seen_at = datetime('now') WHERE id = ?`).bind(user.id).run();
  return { items, seenAt, unread };
}

/** 헤더 배지용 안 읽은 알림 수 (0이면 배지 없음) — 실패해도 0 */
export async function fetchUnreadCount(user: SessionUser): Promise<number> {
  try {
    const db = await getDb();
    const row = await db.prepare(`
      SELECT (
        (SELECT COUNT(*) FROM comments c JOIN posts p ON p.id = c.post_id
          WHERE p.user_id = ?1 AND (c.user_id IS NULL OR c.user_id != ?1) AND c.hidden = 0
            AND c.created_at <= datetime('now') AND c.created_at > ?2 AND ${visibleTo(user.id, 'c.user_id', 'c.resident_id')})
        + (SELECT COUNT(*) FROM comments c JOIN comments parent ON parent.id = c.parent_id
          WHERE parent.user_id = ?1 AND (c.user_id IS NULL OR c.user_id != ?1) AND c.hidden = 0
            AND c.created_at <= datetime('now') AND c.created_at > ?2 AND ${visibleTo(user.id, 'c.user_id', 'c.resident_id')})
        + (SELECT COUNT(*) FROM follows f WHERE f.target_type = 'user' AND f.target_id = ?1 AND f.created_at > ?2)
        + (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id = l.post_id WHERE p.user_id = ?1 AND l.user_id != ?1 AND l.created_at > ?2 AND ${visibleTo(user.id, 'l.user_id', 'NULL')})
        + (SELECT COUNT(*) FROM resident_likes rl JOIN posts p ON p.id = rl.post_id
          WHERE p.user_id = ?1 AND rl.created_at <= datetime('now') AND rl.created_at > ?2 AND ${visibleTo(user.id, 'NULL', 'rl.resident_id')})
      ) AS n`)
      .bind(user.id, await seenOf(db, user.id)).first<{ n: number }>();
    return row?.n ?? 0;
  } catch { return 0; }
}

async function seenOf(db: D1Database, userId: number): Promise<string> {
  const row = await db.prepare(`SELECT COALESCE(notifs_seen_at, created_at) AS seen FROM users WHERE id = ?`).bind(userId).first<{ seen: string }>();
  return row?.seen ?? '1970-01-01 00:00:00';
}
