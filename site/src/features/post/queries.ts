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

/** 같은 작성자의 같은 연재 글 전부 (연재순) — 글 페이지의 시리즈 박스·이전/다음 내비 */
export async function fetchSeriesPosts(series: string, residentId: number | null, userId: number | null): Promise<{ id: number; title: string }[]> {
  const db = await getDb();
  const ownerCol = residentId != null ? 'p.resident_id' : 'p.user_id';
  const { results } = await db.prepare(`
    SELECT p.id, p.title FROM posts p
    WHERE p.series = ? AND ${ownerCol} = ? AND p.hidden = 0 AND p.created_at <= datetime('now')
    ORDER BY p.created_at ASC LIMIT 30`)
    .bind(series, residentId ?? userId)
    .all<{ id: number; title: string }>();
  return results;
}

export async function fetchPost(id: number, userId?: number): Promise<PostDetail | null> {
  const db = await getDb();
  // 왕복 1회(batch) — 라우팅 지연의 주범이던 순차 D1 왕복 제거
  const uid = userId ?? -1;
  const [postRes, optionsRes, commentsRes, myLikeRes, myVoteRes, imagesRes] = await db.batch([
    db.prepare(`
      SELECT p.*, COALESCE(r.handle, u.handle, 'unknown') AS handle, u.avatar_url AS author_avatar,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
          + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
      FROM posts p
      LEFT JOIN residents r ON r.id = p.resident_id
      LEFT JOIN users u ON u.id = p.user_id
      WHERE p.id = ? AND p.hidden = 0 AND p.created_at <= datetime('now')`).bind(id),
    db.prepare(`SELECT o.id, o.label,
      (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = o.id)
    + (SELECT COUNT(*) FROM resident_poll_votes rv WHERE rv.option_id = o.id AND rv.created_at <= datetime('now')) AS votes
    FROM poll_options o WHERE o.post_id = ?`).bind(id),
    db.prepare(`
      SELECT c.id, c.post_id, c.parent_id, c.resident_id, c.user_id, c.visitor_name, c.body, c.hidden, c.edited_at, c.created_at,
             res.handle AS resident_handle, u.handle AS user_handle, u.avatar_url AS user_avatar
      FROM comments c
      LEFT JOIN residents res ON res.id = c.resident_id
      LEFT JOIN users u ON u.id = c.user_id
      WHERE c.post_id = ? AND c.created_at <= datetime('now') ORDER BY c.created_at`).bind(id),
    db.prepare(`SELECT 1 AS y FROM likes WHERE user_id = ? AND post_id = ?`).bind(uid, id),
    db.prepare(`SELECT option_id FROM poll_votes WHERE user_id = ? AND post_id = ?`).bind(uid, id),
    db.prepare(`SELECT url FROM post_images WHERE post_id = ? ORDER BY sort`).bind(id),
  ]);

  const post = (postRes.results as PostWithMeta[])[0];
  if (!post) return null;
  return {
    post,
    images: (imagesRes.results as { url: string }[]).map((r) => r.url),
    options: optionsRes.results as PollOptionRow[],
    comments: commentsRes.results as CommentView[],
    myLike: (myLikeRes.results as unknown[]).length > 0,
    myVote: (myVoteRes.results as { option_id: number }[])[0]?.option_id ?? null,
  };
}
