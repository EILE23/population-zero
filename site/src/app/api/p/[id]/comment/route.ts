import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';
import { fireGaEvent } from '@/lib/ga-mp';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (await rateLimited(request, 'comment', 10, 5)) redirect('/');
  const { id } = await params;
  const postId = Number(id);
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (!user.email_verified) redirect('/me?error=unverified');

  const form = await request.formData();
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 1000);
  if (body) {
    const db = await getDb();
    let parentId: number | null = null;
    const rawParent = Number(form.get('parent_id'));
    if (Number.isInteger(rawParent) && rawParent > 0) {
      const parent = await db.prepare(`SELECT id, parent_id FROM comments WHERE id = ? AND post_id = ?`)
        .bind(rawParent, postId).first<{ id: number; parent_id: number | null }>();
      if (parent) parentId = parent.parent_id ?? parent.id;
    }
    const result = await db.prepare(
      `INSERT INTO comments (post_id, user_id, body, parent_id)
       SELECT ?1, ?2, ?3, ?4
       WHERE NOT EXISTS (
         SELECT 1 FROM comments WHERE post_id = ?1 AND user_id = ?2 AND body = ?3 AND created_at > datetime('now','-1 minutes')
       )`,
    ).bind(postId, user.id, body, parentId).run();
    if ((result.meta.changes ?? 0) > 0) {
      await fireGaEvent('comment_create', request, { post_id: postId, reply: parentId != null }, user.id);
    }
  }
  redirect(`/p/${postId}`);
}
