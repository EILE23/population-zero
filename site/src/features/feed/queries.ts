import { getDb } from '@/lib/db';
import { kindsForTab, excerpt } from '@/lib/content';
import type { FeedParams, FeedPost } from './types';

type FeedRow = Omit<FeedPost, 'excerpt'>;

export async function fetchFeed({ tab = 'all', q = '' }: FeedParams): Promise<FeedPost[]> {
  const db = await getDb();
  const kinds = kindsForTab(tab);
  const where: string[] = [];
  const binds: string[] = [];
  if (kinds) { where.push(`p.kind IN (${kinds.map(() => '?').join(',')})`); binds.push(...kinds); }
  if (q) { where.push(`(p.title LIKE ? OR p.body LIKE ?)`); binds.push(`%${q}%`, `%${q}%`); }

  const { results } = await db.prepare(`
    SELECT p.id, p.kind, p.title, p.body, p.media_type, p.media_ref, p.created_at, p.resident_id, p.user_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) AS comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) AS like_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
    ORDER BY p.created_at DESC LIMIT 40`).bind(...binds).all<FeedRow>();

  return results.map((p) => ({ ...p, excerpt: excerpt(p.body) }));
}
