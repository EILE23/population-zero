import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

type Incoming = {
  /** 기기 식별자 — 로그인 전에도 취향을 이어가려고 앱이 만들어 보관한다 */
  anon?: unknown;
  events?: unknown;
};

const ACTIONS = new Set(['view', 'open']);
const ANON = /^[A-Za-z0-9_-]{6,64}$/;
const MAX_EVENTS = 60;

/**
 * 무엇을 보고 무엇을 눌렀는지 기록한다 — Today 순서를 그 사람에게 맞추기 위한 근거.
 * 제목도 본문도 저장하지 않는다: 분류·매체·종류만 남겨 "이 사람은 어떤 걸 고르는가"만 안다.
 *
 * 외부 JSON 은 타입 선언이 아니라 여기서 검증한다. 분류·매체·종류·지역은 클라이언트가 보낸 값이 아니라
 * trend_id 로 서버의 trends 행에서 다시 읽는다 — 임의 문자열이 통계에 섞이지 않게.
 * 같은 사람이 같은 항목에 같은 행동을 6시간 안에 되풀이하면 한 번만 남긴다 (재전송·중복 큐 흡수).
 */
export async function POST(request: Request) {
  const user = await getSessionUser();
  const body = (await request.json().catch(() => null)) as Incoming | null;
  if (!body || typeof body !== 'object') return Response.json({ error: 'bad_json' }, { status: 400 });
  if (!Array.isArray(body.events)) return Response.json({ error: 'events_not_array' }, { status: 400 });
  if (body.events.length > MAX_EVENTS) return Response.json({ error: 'too_many_events' }, { status: 400 });

  const anon = typeof body.anon === 'string' && ANON.test(body.anon) ? body.anon : null;
  if (!user && !anon) return Response.json({ ok: true, stored: 0 });

  // 익명 쓰기라 빈도 제한을 둔다 — IP 당 10분에 40회. 정상 사용은 스크롤 몇 번에 한 번이다.
  if (await rateLimited(request, 'trend-event', 40, 10)) return Response.json({ error: 'rate' }, { status: 429 });

  const wanted = new Map<number, 'view' | 'open'>();
  for (const raw of body.events) {
    if (!raw || typeof raw !== 'object') continue;
    const e = raw as { trend_id?: unknown; action?: unknown };
    if (!Number.isInteger(e.trend_id) || (e.trend_id as number) <= 0) continue;
    if (typeof e.action !== 'string' || !ACTIONS.has(e.action)) continue;
    const id = e.trend_id as number;
    // 같은 항목에 view 와 open 이 함께 오면 open 이 더 강한 신호다
    if (e.action === 'open' || !wanted.has(id)) wanted.set(id, e.action as 'view' | 'open');
  }
  if (!wanted.size) return Response.json({ ok: true, stored: 0 });

  const db = await getDb();
  const ids = [...wanted.keys()];
  const { results: trends } = await db.prepare(
    `SELECT id, topic, source, kind, region FROM trends WHERE id IN (${ids.map(() => '?').join(',')})`,
  ).bind(...ids).all<{ id: number; topic: string | null; source: string; kind: string; region: string | null }>();
  if (!trends.length) return Response.json({ ok: true, stored: 0 });

  const who = user ? `user_id = ?1` : `anon = ?2`;
  const writes = trends.map((t) => db.prepare(
    `INSERT INTO trend_events (user_id, anon, trend_id, action, topic, source, kind, region)
     SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8
     WHERE NOT EXISTS (
       SELECT 1 FROM trend_events WHERE ${who} AND trend_id = ?3 AND action = ?4 AND created_at > datetime('now','-6 hours')
     )`,
  ).bind(user?.id ?? null, user ? null : anon, t.id, wanted.get(t.id)!, t.topic, t.source, t.kind, t.region));
  const results = await db.batch(writes);
  const stored = results.reduce((n, r) => n + (r.meta.changes ?? 0), 0);

  // 보존 기간 — 취향 신호는 오래된 것일수록 뜻이 없다. 백 번에 한 번쯤 90일 넘은 행을 치운다.
  if (Math.random() < 0.01) await db.prepare(`DELETE FROM trend_events WHERE created_at < datetime('now','-90 days')`).run();

  return Response.json({ ok: true, stored });
}
