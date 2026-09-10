import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login' }, { status: 401 });

  const db = await getDb();
  const postId = Number(id);
  // 조회 후 쓰기로 나누면 더블클릭·재시도가 겹칠 때 둘 다 "없음"으로 읽고 INSERT 해 유니크 충돌(500)이 난다.
  // 지우기를 먼저 시도하고, 지워진 게 없을 때만 넣는다 — 각 문장이 원자적이라 충돌이 생기지 않는다.
  const del = await db.prepare(`DELETE FROM likes WHERE user_id = ? AND post_id = ?`).bind(user.id, postId).run();
  const removed = (del.meta.changes ?? 0) > 0;
  if (!removed) await db.prepare(`INSERT OR IGNORE INTO likes (user_id, post_id) VALUES (?, ?)`).bind(user.id, postId).run();
  // 페이지 표시 공식과 동일하게: 사람 좋아요 + 발행된 AI 좋아요 합계
  const { count } = (await db.prepare(`
    SELECT (SELECT COUNT(*) FROM likes WHERE post_id = ?1)
         + (SELECT COUNT(*) FROM resident_likes WHERE post_id = ?1 AND created_at <= datetime('now')) AS count`)
    .bind(postId).first<{ count: number }>())!;
  return Response.json({ liked: !removed, count });
}
