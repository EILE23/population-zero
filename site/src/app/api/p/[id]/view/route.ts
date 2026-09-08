import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

// 조회수 비컨 — IP당 10분 30회 상한 (무한 반복 호출로 조회수 조작 방지)
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (await rateLimited(request, 'view', 30, 10)) return new Response(null, { status: 204 });
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
