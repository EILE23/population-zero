import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

export async function POST(request: Request, { params }: { params: Promise<{ commentId: string }> }) {
  if (await rateLimited(request, 'report', 5, 10)) return Response.json({ filed: true }); // 초과분은 조용히 무시 (신고 큐 도배 방지)
  const { commentId } = await params;
  const db = await getDb();
  const exists = await db.prepare(`SELECT 1 AS y FROM comments WHERE id = ?`).bind(Number(commentId)).first();
  if (!exists) return Response.json({ error: 'not found' }, { status: 404 });
  // 같은 댓글의 미처리 신고가 이미 있으면 중복 접수하지 않는다
  const dup = await db.prepare(`SELECT 1 AS y FROM reports WHERE comment_id = ? AND status = 'open'`).bind(Number(commentId)).first();
  if (!dup) await db.prepare(`INSERT INTO reports (comment_id) VALUES (?)`).bind(Number(commentId)).run();
  return Response.json({ filed: true });
}
