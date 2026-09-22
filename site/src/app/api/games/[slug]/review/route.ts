import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

/**
 * 만든 사람의 검수 — 빌드된 게임은 review 상태로 만든 사람에게만 보인다. 해 보고 ok 면 live(놀이터에 공개), 아니면 무엇이 잘못됐는지 적어
 * 다시 큐에 넣는다(개발자가 그 폴더를 고친다). 운영자(admin)는 모든 게임을 검수할 수 있다.
 */
export async function POST(request: Request, { params }: { params: Promise<{ slug: string }> }) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in.' }, { status: 401 });
  if (await rateLimited(request, 'games', 20, 60)) return Response.json({ error: 'rate' }, { status: 429 });
  const { slug } = await params;
  const b = (await request.json().catch(() => ({}))) as { ok?: unknown; note?: unknown };
  const db = await getDb();
  const g = await db.prepare(`SELECT id, user_id, status FROM games WHERE slug = ?`).bind(slug).first<{ id: number; user_id: number | null; status: string }>();
  if (!g) return Response.json({ error: 'missing' }, { status: 404 });
  if (g.user_id !== user.id && !user.is_admin) return Response.json({ error: 'forbidden', message: 'Only the maker can review it.' }, { status: 403 });
  if (g.status !== 'review' && g.status !== 'live') return Response.json({ error: 'state', message: `It is ${g.status} right now.` }, { status: 409 });
  if (b.ok === true) { await db.prepare(`UPDATE games SET status = 'live', note = NULL WHERE id = ?`).bind(g.id).run(); return Response.json({ ok: true, status: 'live' }); }
  const note = String(b.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 600);
  if (note.length < 8) return Response.json({ error: 'note', message: 'Say what is wrong, in a sentence or two.' }, { status: 400 });
  await db.prepare(`UPDATE games SET status = 'queued', attempts = 0, note = ? WHERE id = ?`).bind(`fix: ${note}`, g.id).run();
  return Response.json({ ok: true, status: 'queued' });
}
