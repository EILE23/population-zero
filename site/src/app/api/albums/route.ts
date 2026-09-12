import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { visibleTo } from '@/lib/safety';

type AlbumRow = {
  id: number;
  title: string;
  topic: string | null;
  created_at: string;
  handle: string;
  user_id: number | null;
  resident_id: number | null;
  cover: string | null;
  shot_count: number;
  like_count: number;
  comment_count: number;
};

/**
 * 앨범 — 사진 여러 장이 한 묶음으로 올라간 글.
 * 앱 전용 개념이라 웹 피드와 따로 둔다: 웹은 글을 읽는 곳, 앱의 앨범은 사진을 넘겨보는 곳.
 * author 를 주면 그 사람 앨범만 (Me 화면).
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const author = url.searchParams.get('author');
  const mineOnly = url.searchParams.get('mine') === '1';
  const offset = Math.max(0, Number(url.searchParams.get('offset')) || 0);
  const limit = Math.min(30, Math.max(1, Number(url.searchParams.get('limit')) || 12));

  const where: string[] = [`p.hidden = 0`, `p.created_at <= datetime('now')`];
  const binds: (string | number)[] = [];
  const viewer = await getSessionUser();
  where.push(visibleTo(viewer?.id ?? 0, 'p.user_id', 'p.resident_id'));
  if (author) { where.push(`COALESCE(r.handle, u.handle) = ?`); binds.push(author); }
  if (mineOnly) {
    const me = await getSessionUser();
    if (!me) return Response.json({ error: 'unauthorized' }, { status: 401 });
    where.push(`p.user_id = ?`);
    binds.push(me.id);
  }

  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT p.id, p.title, p.topic, p.created_at, p.user_id, p.resident_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle,
      (SELECT pi.url FROM post_images pi WHERE pi.post_id = p.id ORDER BY pi.sort LIMIT 1) AS cover,
      (SELECT COUNT(*) FROM post_images pi WHERE pi.post_id = p.id) AS shot_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    WHERE ${where.join(' AND ')} AND EXISTS (SELECT 1 FROM post_images pi WHERE pi.post_id = p.id)
    ORDER BY p.created_at DESC LIMIT ? OFFSET ?`)
    .bind(...binds, limit, offset).all<AlbumRow>();

  // 앱은 앨범을 전체화면으로 한 장씩 넘겨 보므로 사진 전부를 함께 내려준다
  const ids = results.map((a) => a.id);
  const shots = ids.length
    ? (await db.prepare(
        `SELECT post_id, url, sort FROM post_images WHERE post_id IN (${ids.map(() => '?').join(',')}) ORDER BY post_id, sort`,
      ).bind(...ids).all<{ post_id: number; url: string; sort: number }>()).results
    : [];

  return Response.json(
    results.map((a) => ({
      ...a,
      images: shots.filter((s) => s.post_id === a.id).map((s) => s.url),
    })),
    { headers: { 'x-poz-country': request.headers.get('cf-ipcountry') ?? '' } },
  );
}
