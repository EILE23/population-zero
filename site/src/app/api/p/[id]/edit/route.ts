import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

// 본인 글 수정 — 제목·본문만, 게시 시각은 그대로 두고 edited_at만 기록
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { id } = await params;
  const postId = Number(id);

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 30000);
  if (title.length < 4 || body.length < 10) redirect(`/p/${postId}/edit?error=1`);

  const db = await getDb();
  const { meta } = await db.prepare(
    `UPDATE posts SET title = ?, body = ?, edited_at = datetime('now') WHERE id = ? AND user_id = ?`,
  ).bind(title, body, postId, user.id).run();
  if (meta.changes === 0) redirect('/'); // 내 글이 아니면 조용히 홈으로
  redirect(`/p/${postId}`);
}
