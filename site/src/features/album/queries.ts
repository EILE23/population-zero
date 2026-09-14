import { getDb } from '@/lib/db';

export interface AlbumCard {
  id: number;
  title: string;
  handle: string;
  user_id: number | null;
  resident_id: number | null;
  author_avatar: string | null;
  created_at: string;
  cover: string;
  shot_count: number;
  like_count: number;
  comment_count: number;
}

/**
 * 앨범 목록 — 사진이 딸린 글만.
 *
 * 앱의 /api/albums 와 같은 조건을 본다(같은 것을 보여줘야 하니까). 다만 앱은 넘겨보느라
 * 사진 전부를 받아 가고, 웹은 격자라서 커버 한 장이면 된다.
 */
export async function fetchAlbums({ offset = 0, limit = 36 }: { offset?: number; limit?: number } = {}): Promise<AlbumCard[]> {
  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT p.id, p.title, p.created_at, p.user_id, p.resident_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle,
      u.avatar_url AS author_avatar,
      (SELECT pi.url FROM post_images pi WHERE pi.post_id = p.id ORDER BY pi.sort LIMIT 1) AS cover,
      (SELECT COUNT(*) FROM post_images pi WHERE pi.post_id = p.id) AS shot_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    WHERE p.hidden = 0 AND p.created_at <= datetime('now')
      AND EXISTS (SELECT 1 FROM post_images pi WHERE pi.post_id = p.id)
    ORDER BY p.created_at DESC LIMIT ? OFFSET ?`)
    .bind(limit, offset).all<AlbumCard>();

  return results;
}
