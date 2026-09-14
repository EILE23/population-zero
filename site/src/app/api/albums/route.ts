import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { visibleTo } from '@/lib/safety';

type AlbumRow = {
  album_id: number;
  id: number;              // origin 글 id — 좋아요·댓글·상세 화면은 이 글로 간다
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
  liked: number;
};

/**
 * 앨범 — 독립 객체. 앱의 릴스 화면이 넘겨 보는 목록.
 * 각 앨범은 처음 올라온 글(origin)을 갖고, 반응(좋아요·댓글)은 그 글에 쌓인다.
 * 그래서 응답의 `id` 는 origin 글 id 다(앱이 그대로 좋아요·댓글·상세에 쓴다). 앨범 자체 id 는 `album_id`.
 * author 를 주면 그 사람 앨범만, mine=1 이면 내 앨범만(글에 붙일 앨범을 고를 때).
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const author = url.searchParams.get('author');
  const mineOnly = url.searchParams.get('mine') === '1';
  const offset = Math.max(0, Number(url.searchParams.get('offset')) || 0);
  const limit = Math.min(30, Math.max(1, Number(url.searchParams.get('limit')) || 12));

  // 내 좋아요 여부를 같이 내려줘야 앱에서 하트가 채워진 채로 돌아온다
  const me = await getSessionUser();

  const where: string[] = [`p.hidden = 0`, `p.created_at <= datetime('now')`];
  const binds: (string | number)[] = [];
  where.push(visibleTo(me?.id ?? 0, 'a.user_id', 'a.resident_id'));
  if (author) { where.push(`COALESCE(r.handle, u.handle) = ?`); binds.push(author); }
  if (mineOnly) {
    if (!me) return Response.json({ error: 'unauthorized' }, { status: 401 });
    where.push(`a.user_id = ?`);
    binds.push(me.id);
  }

  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT a.id AS album_id, p.id, p.title, p.topic, a.created_at, a.user_id, a.resident_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle,
      (SELECT ai.url FROM album_images ai WHERE ai.album_id = a.id ORDER BY ai.sort LIMIT 1) AS cover,
      (SELECT COUNT(*) FROM album_images ai WHERE ai.album_id = a.id) AS shot_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count,
      EXISTS (SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) AS liked
    FROM albums a
    JOIN posts p ON p.id = a.origin_post_id
    LEFT JOIN residents r ON r.id = a.resident_id
    LEFT JOIN users u ON u.id = a.user_id
    WHERE ${where.join(' AND ')} AND EXISTS (SELECT 1 FROM album_images ai WHERE ai.album_id = a.id)
    ORDER BY a.created_at DESC LIMIT ? OFFSET ?`)
    // ? 순서는 SQL 에 나타난 순서 — liked 서브쿼리가 SELECT 절에 있어 뷰어 id 가 맨 앞이다
    .bind(me?.id ?? 0, ...binds, limit, offset).all<AlbumRow>();

  // 앱은 앨범을 전체화면으로 한 장씩 넘겨 보므로 사진 전부를 함께 내려준다
  const ids = results.map((a) => a.album_id);
  const shots = ids.length
    ? (await db.prepare(
        `SELECT album_id, url, sort FROM album_images WHERE album_id IN (${ids.map(() => '?').join(',')}) ORDER BY album_id, sort`,
      ).bind(...ids).all<{ album_id: number; url: string; sort: number }>()).results
    : [];

  return Response.json(
    results.map((a) => ({
      ...a,
      liked: a.liked === 1,
      images: shots.filter((s) => s.album_id === a.album_id).map((s) => s.url),
    })),
    { headers: { 'x-poz-country': request.headers.get('cf-ipcountry') ?? '' } },
  );
}
