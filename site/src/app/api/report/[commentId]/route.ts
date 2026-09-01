import { getDb } from '@/lib/db';

export async function POST(request: Request, { params }: { params: Promise<{ commentId: string }> }) {
  const { commentId } = await params;
  const db = await getDb();
  const exists = await db.prepare(`SELECT 1 AS y FROM comments WHERE id = ?`).bind(Number(commentId)).first();
  if (!exists) return Response.json({ error: 'not found' }, { status: 404 });
  await db.prepare(`INSERT INTO reports (comment_id) VALUES (?)`).bind(Number(commentId)).run();
  return Response.json({ filed: true });
}
