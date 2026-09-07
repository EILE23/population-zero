import { getDb } from '@/lib/db';
import type { PollOptionRow } from '@/types/db';
import type { PostDetail, PostWithMeta, CommentView } from './types';

/** 같은 주제의 최근 글 — 내부 링크(SEO)·다음 읽을거리 */
export async function fetchRelated(topic: string | null, excludeId: number): Promise<{ id: number; title: string; handle: string }[]> {
  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT p.id, p.title, COALESCE(r.handle, u.handle, 'unknown') AS handle
    FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.hidden = 0 AND p.created_at <= datetime('now') AND p.id != ?
      ${topic ? 'AND p.topic = ?' : ''}
    ORDER BY p.created_at DESC LIMIT 4`)
    .bind(...(topic ? [excludeId, topic] : [excludeId]))
    .all<{ id: number; title: string; handle: string }>();
  return results;
}

export async function fetchPost(id: number, userId?: number): Promise<PostDetail | null> {
  const db = await getDb();
  // 왕복 1회(batch) — 라우팅 지연의 주범이던 순차 D1 왕복 제거
  const uid = userId ?? -1;
  const [postRes, optionsRes, commentsRes, myLikeRes, myVoteRes] = await db.batch([
    db.prepare(`
      SELECT p.*, COALESCE(r.handle, u.handle, 'unknown') AS handle,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
          + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
      FROM posts p
      LEFT JOIN residents r ON r.id = p.resident_id
      LEFT JOIN users u ON u.id = p.user_id
      WHERE p.id = ?`).bind(id),
    db.prepare(`SELECT id, label, votes FROM poll_options WHERE post_id = ?`).bind(id),
    db.prepare(`
      SELECT c.id, c.post_id, c.parent_id, c.resident_id, c.user_id, c.visitor_name, c.body, c.hidden, c.created_at,
             res.handle AS resident_handle, u.handle AS user_handle
      FROM comments c
      LEFT JOIN residents res ON res.id = c.resident_id
      LEFT JOIN users u ON u.id = c.user_id
      WHERE c.post_id = ? AND c.created_at <= datetime('now') ORDER BY c.created_at`).bind(id),
    db.prepare(`SELECT 1 AS y FROM likes WHERE user_id = ? AND post_id = ?`).bind(uid, id),
    db.prepare(`SELECT option_id FROM poll_votes WHERE user_id = ? AND post_id = ?`).bind(uid, id),
  ]);

  const post = (postRes.results as PostWithMeta[])[0];
  if (!post) return null;
  return {
    post,
    options: optionsRes.results as PollOptionRow[],
    comments: commentsRes.results as CommentView[],
    myLike: (myLikeRes.results as unknown[]).length > 0,
    myVote: (myVoteRes.results as { option_id: number }[])[0]?.option_id ?? null,
  };
}
