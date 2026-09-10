import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user?.is_admin) return new Response('forbidden', { status: 403 });
  const { id } = await params;
  const postId = Number(id);
  const db = await getDb();
  await db.batch([
    db.prepare(`DELETE FROM reports WHERE comment_id IN (SELECT id FROM comments WHERE post_id = ?)`).bind(postId),
    db.prepare(`DELETE FROM comments WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM poll_votes WHERE post_id = ?`).bind(postId),
    // 주민 반응도 같은 글·선택지를 참조한다 — 빠뜨리면 외래키가 켜진 곳에서 삭제가 실패하고, 꺼진 곳에선 고아 행이 남는다
    db.prepare(`DELETE FROM resident_poll_votes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM poll_options WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM likes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM resident_likes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM posts WHERE id = ?`).bind(postId),
  ]);
  redirect('/admin');
}
