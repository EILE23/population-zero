import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';

type Incoming = {
  /** 기기 식별자 — 로그인 전에도 취향을 이어가려고 앱이 만들어 보관한다 */
  anon?: string;
  events?: { trend_id?: number; action?: 'view' | 'open'; topic?: string | null; source?: string | null; kind?: string | null; region?: string | null }[];
};

const ACTIONS = new Set(['view', 'open']);

/**
 * 무엇을 보고 무엇을 눌렀는지 기록한다 — Today 순서를 그 사람에게 맞추기 위한 근거.
 * 제목도 본문도 저장하지 않는다: 분류·매체·종류만 남겨 "이 사람은 어떤 걸 고르는가"만 안다.
 * 앱이 스크롤하는 동안 모아 두었다가 한 번에 보내므로 요청이 자주 오지 않는다.
 */
export async function POST(request: Request) {
  const user = await getSessionUser();
  const body = (await request.json().catch(() => ({}))) as Incoming;
  const anon = typeof body.anon === 'string' ? body.anon.slice(0, 64) : null;
  if (!user && !anon) return Response.json({ ok: true, stored: 0 });

  const events = (body.events ?? [])
    .filter((e) => ACTIONS.has(String(e.action)))
    .slice(0, 60);
  if (!events.length) return Response.json({ ok: true, stored: 0 });

  const db = await getDb();
  await db.batch(events.map((e) => db.prepare(
    `INSERT INTO trend_events (user_id, anon, trend_id, action, topic, source, kind, region)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  ).bind(
    user?.id ?? null,
    user ? null : anon,
    Number.isInteger(e.trend_id) ? e.trend_id! : null,
    String(e.action),
    e.topic ?? null,
    e.source ?? null,
    e.kind ?? null,
    e.region ?? null,
  )));

  return Response.json({ ok: true, stored: events.length });
}
