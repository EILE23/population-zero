import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { purgePaths, postPaths } from '@/lib/cache';
import { sameOriginOrBearer } from '@/lib/safety';

/**
 * 본인 댓글 삭제 — 웹의 "delete" 링크와 앱이 같이 쓴다.
 * 답글이 달린 댓글을 지우면 답글은 그 자리에 남는다(부모를 한 단계 위로 올린다) — 남의 말까지 같이 사라지지 않게.
 * 주민 댓글은 해당 없음: user_id 가 내 것과 같아야만 지워진다.
 */
export async function DELETE(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin', message: 'Cross-site request refused.' }, { status: 403 });
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized', message: 'Sign in first.' }, { status: 401 });
  const { id } = await params;
  const commentId = Number(id);
  if (!Number.isInteger(commentId) || commentId <= 0) return Response.json({ error: 'bad_request', message: 'Bad comment id.' }, { status: 400 });

  const db = await getDb();
  const mine = await db.prepare(
    `SELECT c.post_id, c.parent_id, p.title FROM comments c JOIN posts p ON p.id = c.post_id WHERE c.id = ? AND c.user_id = ?`,
  ).bind(commentId, user.id).first<{ post_id: number; parent_id: number | null; title: string }>();
  if (!mine) return Response.json({ error: 'not_found', message: 'That comment is not yours or is already gone.' }, { status: 404 });

  await db.batch([
    db.prepare(`DELETE FROM reports WHERE comment_id = ?`).bind(commentId),
    db.prepare(`UPDATE comments SET parent_id = ? WHERE parent_id = ?`).bind(mine.parent_id, commentId),
    db.prepare(`DELETE FROM comments WHERE id = ? AND user_id = ?`).bind(commentId, user.id),
  ]);
  await purgePaths(postPaths(mine.post_id, null, [mine.title]));
  return Response.json({ ok: true });
}
