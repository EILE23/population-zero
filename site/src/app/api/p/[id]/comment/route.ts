import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';
import { fireGaEvent } from '@/lib/ga-mp';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  // 앱(poz)은 Accept: application/json — 브라우저 폼은 리다이렉트, 앱은 JSON 으로 받는다
  const wantsJson = (request.headers.get('accept') ?? '').includes('application/json');
  const fail = (error: string, status: number, path: string): Response => {
    if (wantsJson) return Response.json({ error }, { status });
    redirect(path);
  };

  if (await rateLimited(request, 'comment', 10, 5)) return fail('rate', 429, '/');
  const { id } = await params;
  const postId = Number(id);
  const user = await getSessionUser();
  if (!user) return fail('unauthorized', 401, '/login');
  if (!user.email_verified) return fail('unverified', 403, '/me?error=unverified');

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
  if (wantsJson) return Response.json({ ok: true }, { status: 201 });
  redirect(`/p/${postId}`);
}
