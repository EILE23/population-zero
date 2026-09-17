import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';

const MAX_ALERTS = 20;
const REGIONS = ['', 'KR', 'US', 'GB', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG'];

/**
 * 키워드 알림 — "이 단어가 기사에 뜨면 메일로 알려줘".
 * 순찰이 이미 12개국 기사를 하루 여덟 번 모아 둔다. 여기서 하는 일은 그 위에 단어를 걸어 두는 것뿐이고,
 * 매칭과 발송은 워커의 시간당 크론이 한다(모델 호출 없음). 게스트는 못 만든다 — 메일 주소가 있어야 하니까.
 */
export async function GET() {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ alerts: [] });
  const { results } = await (await getDb())
    .prepare(`SELECT id, keyword, region, created_at FROM alerts WHERE user_id = ? ORDER BY created_at DESC`)
    .bind(user.id).all();
  return Response.json({ alerts: results }, { headers: { 'cache-control': 'no-store' } });
}

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Make an account to get alerts by email.' }, { status: 401 });

  const body = (await request.json().catch(() => ({}))) as { keyword?: unknown; region?: unknown; remove?: unknown };
  const db = await getDb();

  if (Number.isInteger(body.remove)) {
    await db.batch([
      db.prepare(`DELETE FROM alert_sent WHERE alert_id = ? AND alert_id IN (SELECT id FROM alerts WHERE user_id = ?)`).bind(body.remove, user.id),
      db.prepare(`DELETE FROM alerts WHERE id = ? AND user_id = ?`).bind(body.remove, user.id),
    ]);
    return Response.json({ ok: true });
  }

  const keyword = String(body.keyword ?? '').replace(/\s+/g, ' ').trim().toLowerCase().slice(0, 60);
  const region = REGIONS.includes(String(body.region ?? '')) ? String(body.region ?? '') : '';
  if (keyword.length < 2) return Response.json({ error: 'short', message: 'Two characters at least.' }, { status: 400 });

  const [count] = (await db.prepare(`SELECT COUNT(*) AS n FROM alerts WHERE user_id = ?`).bind(user.id).all<{ n: number }>()).results;
  if ((count?.n ?? 0) >= MAX_ALERTS) return Response.json({ error: 'limit', message: `${MAX_ALERTS} alerts is the limit.` }, { status: 429 });

  await db.prepare(`INSERT OR IGNORE INTO alerts (user_id, keyword, region) VALUES (?, ?, ?)`).bind(user.id, keyword, region).run();
  // 처음 등록하면 지난 기사는 보내지 않는다 — 이미 있는 것까지 한꺼번에 오면 알림이 아니라 스팸이다
  await db.prepare(
    `INSERT OR IGNORE INTO alert_sent (alert_id, trend_id)
     SELECT a.id, t.id FROM alerts a JOIN trends t
     WHERE a.user_id = ? AND a.keyword = ? AND a.region = ? AND t.kind = 'news'`,
  ).bind(user.id, keyword, region).run();
  return Response.json({ ok: true });
}
