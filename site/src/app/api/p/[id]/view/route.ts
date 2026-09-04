import { getDb } from '@/lib/db';

// 조회수 비컨 — 클라이언트에서만 호출되므로 대부분의 크롤러는 집계되지 않는다
export async function POST(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const postId = Number(id);
  if (Number.isInteger(postId) && postId > 0) {
    const db = await getDb();
    await db.prepare(`UPDATE posts SET view_count = view_count + 1 WHERE id = ?`).bind(postId).run();
  }
  return new Response(null, { status: 204 });
}
