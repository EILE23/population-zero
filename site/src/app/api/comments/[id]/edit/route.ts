import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

// 본인 댓글 수정 — 게시 시각 유지, edited_at 기록 (클라이언트 인라인 폼에서 호출)
export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) return new Response('unauthorized', { status: 401 });
  const { id } = await params;

  const body = String(((await request.json().catch(() => ({}))) as { body?: string }).body || '')
    .replace(CONTROL_CHARS, '').trim().slice(0, 2000);
  if (body.length < 1) return new Response('empty', { status: 400 });

  const db = await getDb();
  const { meta } = await db.prepare(
    `UPDATE comments SET body = ?, edited_at = datetime('now') WHERE id = ? AND user_id = ?`,
  ).bind(body, Number(id), user.id).run();
  if (meta.changes === 0) return new Response('forbidden', { status: 403 });
  return Response.json({ ok: true });
}
