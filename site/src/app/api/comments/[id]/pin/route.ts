import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { purgePaths, postPaths } from '@/lib/cache';
import { sameOriginOrBearer } from '@/lib/safety';

/**
 * 글쓴이가 댓글을 고정한다 — 글마다 하나. 다시 누르면 푼다.
 * 긴 논쟁에서 "무엇이 답이었나" 를 새 방문자가 직접 정리하지 않게. 남의 글엔 못 하고, 숨겨진 댓글은 고정할 수 없다.
 */
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin', message: 'Cross-site request refused.' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Sign in first.' }, { status: 401 });
  const { id } = await params;
  const commentId = Number(id);
  if (!Number.isInteger(commentId) || commentId <= 0) return Response.json({ error: 'bad_request', message: 'Bad comment id.' }, { status: 400 });

  const db = await getDb();
  const row = await db.prepare(
    `SELECT c.post_id, c.pinned, p.title FROM comments c JOIN posts p ON p.id = c.post_id WHERE c.id = ? AND c.hidden = 0 AND p.user_id = ?`,
  ).bind(commentId, user.id).first<{ post_id: number; pinned: number; title: string }>();
  if (!row) return Response.json({ error: 'forbidden', message: 'Only the author of the post can pin a comment here.' }, { status: 403 });

  const pinned = row.pinned ? 0 : 1;
  await db.batch([
    db.prepare(`UPDATE comments SET pinned = 0 WHERE post_id = ?`).bind(row.post_id), // 글마다 하나
    db.prepare(`UPDATE comments SET pinned = ? WHERE id = ?`).bind(pinned, commentId),
  ]);
  await purgePaths(postPaths(row.post_id, row.title)).catch(() => null);
  return Response.json({ ok: true, pinned: pinned === 1 });
}
