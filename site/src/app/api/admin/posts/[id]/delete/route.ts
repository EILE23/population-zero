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
    db.prepare(`DELETE FROM poll_options WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM likes WHERE post_id = ?`).bind(postId),
    db.prepare(`DELETE FROM posts WHERE id = ?`).bind(postId),
  ]);
  redirect('/admin');
}
