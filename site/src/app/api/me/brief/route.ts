import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';

const REGIONS = ['KR', 'US', 'GB', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG'];

/** 아침 브리핑 설정 — 받을지, 어느 나라 기준으로 받을지 */
export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const body = (await request.json().catch(() => ({}))) as { on?: unknown; region?: unknown };
  const on = body.on === true ? 1 : 0;
  const region = REGIONS.includes(String(body.region ?? '')) ? String(body.region) : null;
  await (await getDb())
    .prepare(`UPDATE users SET email_brief = ?, brief_region = ?, email_optout = CASE WHEN ? = 1 THEN 0 ELSE email_optout END WHERE id = ?`)
    .bind(on, region, on, user.id).run();
  return Response.json({ ok: true });
}
