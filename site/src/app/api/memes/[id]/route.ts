import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';
import { purgePaths } from '@/lib/cache';
import { memeHref } from '@/lib/memes';

/** 삭제 — 올린 사람 본인 또는 관리자. 행은 남기고 hidden 으로(리믹스가 가리킬 수 있다). 앱도 같은 경로(Bearer) */
export async function DELETE(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in first.' }, { status: 401 });
  const { id: raw } = await params;
  const id = /^\d+$/.test(raw) ? Number(raw) : 0;
  if (!id) return Response.json({ error: 'id' }, { status: 400 });
  const db = await getDb();
  const m = await db.prepare(`SELECT user_id FROM memes WHERE id = ? AND hidden = 0`).bind(id).first<{ user_id: number | null }>();
  if (!m) return Response.json({ error: 'not_found', message: 'Already gone.' }, { status: 404 });
  if (m.user_id !== user.id && !user.is_admin) return Response.json({ error: 'forbidden', message: 'Not yours.' }, { status: 403 });
  await db.prepare(`UPDATE memes SET hidden = 1 WHERE id = ?`).bind(id).run();
  await purgePaths(['/memes', memeHref(id)]).catch(() => null);
  return Response.json({ ok: true });
}
