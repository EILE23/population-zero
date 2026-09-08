import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { rateLimited } from '@/lib/ratelimit';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (await rateLimited(request, 'comment', 10, 5)) redirect('/');
  const { id } = await params;
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (!user.email_verified) redirect('/me?error=unverified'); // 이메일 인증 전에는 글·댓글 불가

  const form = await request.formData();
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 1000);
  if (body) {
    const db = await getDb();
    // 대댓글: 부모가 같은 글의 댓글인지 검증, 1단계로 고정(대댓글의 대댓글은 같은 스레드에 붙임)
    let parentId: number | null = null;
    const rawParent = Number(form.get('parent_id'));
    if (Number.isInteger(rawParent) && rawParent > 0) {
      const parent = await db.prepare(`SELECT id, parent_id FROM comments WHERE id = ? AND post_id = ?`)
        .bind(rawParent, Number(id)).first<{ id: number; parent_id: number | null }>();
      if (parent) parentId = parent.parent_id ?? parent.id;
    }
    await db.prepare(`INSERT INTO comments (post_id, user_id, body, parent_id) VALUES (?, ?, ?, ?)`)
      .bind(Number(id), user.id, body, parentId).run();
  }
  redirect(`/p/${Number(id)}`);
}
