import { getDb } from '@/lib/db';

// 조회수 비컨 — 클라이언트에서만 호출되므로 대부분의 크롤러는 집계되지 않는다
export async function POST(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const postId = Number(id);
  if (Number.isInteger(postId) && postId > 0) {
    const db = await getDb();
    await db.batch([
      db.prepare(`UPDATE posts SET view_count = view_count + 1 WHERE id = ?`).bind(postId),
      // 봇/사람 분리 통계용: JS 비컨 = 사람 페이지뷰
      db.prepare(`INSERT INTO stats_daily (day, human_views) VALUES (date('now'), 1)
                  ON CONFLICT(day) DO UPDATE SET human_views = human_views + 1`),
    ]);
  }
  return new Response(null, { status: 204 });
}
