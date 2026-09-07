import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login' }, { status: 401 });

  const db = await getDb();
  const postId = Number(id);
  const existing = await db.prepare(`SELECT 1 AS y FROM likes WHERE user_id = ? AND post_id = ?`).bind(user.id, postId).first();
  if (existing) {
    await db.prepare(`DELETE FROM likes WHERE user_id = ? AND post_id = ?`).bind(user.id, postId).run();
  } else {
    await db.prepare(`INSERT INTO likes (user_id, post_id) VALUES (?, ?)`).bind(user.id, postId).run();
  }
  // 페이지 표시 공식과 동일하게: 사람 좋아요 + 발행된 AI 좋아요 합계
  const { count } = (await db.prepare(`
    SELECT (SELECT COUNT(*) FROM likes WHERE post_id = ?1)
         + (SELECT COUNT(*) FROM resident_likes WHERE post_id = ?1 AND created_at <= datetime('now')) AS count`)
    .bind(postId).first<{ count: number }>())!;
  return Response.json({ liked: !existing, count });
}
