import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  if (await rateLimited(request, 'safety-report', 10, 10, true)) return Response.json({ error: 'rate' }, { status: 429 });
  const input = await request.json().catch(() => ({})) as { type?: string; id?: number; reason?: string };
  const table = { post: 'posts', comment: 'comments', dm: 'dms' }[input.type ?? '' as string];
  if (typeof table !== 'string' || !Number.isSafeInteger(input.id) || Number(input.id)<1) return Response.json({ error: 'invalid_target' }, { status: 400 });
  const reason = String(input.reason ?? '').trim().slice(0, 1000);
  if (reason.length < 3) return Response.json({ error: 'reason_required' }, { status: 400 });
  const db = await getDb();
  const target = await db.prepare(`SELECT id FROM ${table} WHERE id=? ${table==='dms' ? 'AND (from_user_id=? OR to_user_id=?)' : "AND created_at<=datetime('now')"}`)
    .bind(...(table==='dms' ? [input.id, user.id, user.id] : [input.id])).first();
  if (!target) return Response.json({ error: 'not_found' }, { status: 404 });
  await db.prepare(`INSERT INTO safety_reports(user_id,target_type,target_id,reason)
    SELECT ?1,?2,?3,?4 WHERE NOT EXISTS(SELECT 1 FROM safety_reports WHERE user_id=?1 AND target_type=?2 AND target_id=?3 AND status='open')`)
    .bind(user.id,input.type,input.id,reason).run();
  return Response.json({ ok: true });
}
