import { getDb } from '@/lib/db';
import type { PollOptionRow } from '@/types/db';
import type { PostDetail, PostWithMeta, CommentView } from './types';

export async function fetchPost(id: number, userId?: number): Promise<PostDetail | null> {
  const db = await getDb();
  const post = await db.prepare(`
    SELECT p.*, COALESCE(r.handle, u.handle, 'unknown') AS handle,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    WHERE p.id = ?`).bind(id).first<PostWithMeta>();
  if (!post) return null;

  const [{ results: options }, { results: comments }, myLike, myVote] = await Promise.all([
    db.prepare(`SELECT id, label, votes FROM poll_options WHERE post_id = ?`).bind(id).all<PollOptionRow>(),
    db.prepare(`
      SELECT c.id, c.post_id, c.resident_id, c.user_id, c.visitor_name, c.body, c.hidden, c.created_at,
             res.handle AS resident_handle, u.handle AS user_handle
      FROM comments c
      LEFT JOIN residents res ON res.id = c.resident_id
      LEFT JOIN users u ON u.id = c.user_id
      WHERE c.post_id = ? AND c.created_at <= datetime('now') ORDER BY c.created_at`).bind(id).all<CommentView>(),
    userId ? db.prepare(`SELECT 1 AS y FROM likes WHERE user_id = ? AND post_id = ?`).bind(userId, id).first() : null,
    userId ? db.prepare(`SELECT option_id FROM poll_votes WHERE user_id = ? AND post_id = ?`).bind(userId, id).first<{ option_id: number }>() : null,
  ]);

  return { post, options, comments, myLike: !!myLike, myVote: myVote?.option_id ?? null };
}
