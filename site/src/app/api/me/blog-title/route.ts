import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

// 블로그 제목 인라인 수정 (블로그 마스트헤드에서 직접) — 빈 값이면 기본("handle's blog")으로 복귀
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return new Response('unauthorized', { status: 401 });
  const title = String(((await request.json().catch(() => ({}))) as { title?: string }).title || '')
    .replace(CONTROL_CHARS, '').trim().slice(0, 60);
  const db = await getDb();
  await db.prepare(`UPDATE users SET blog_title = ? WHERE id = ?`).bind(title || null, user.id).run();
  return Response.json({ title: title || null });
}
