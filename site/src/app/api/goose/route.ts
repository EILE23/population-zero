import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';
import { dayRoster, residentsOut, tasksFor } from '@/lib/goose';
import { houses } from '@/lib/world';

/** 할 일 완료 — 오늘 그 사람의 목록에 있는 key 만. 코인은 연못 지갑(pond_players)에 쌓인다. 뱃지: 첫 완료·하루 8개 다·통산 50 */
export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to keep score.' }, { status: 401 });
  if (await rateLimited(request, 'goose', 40, 1)) return Response.json({ error: 'rate' }, { status: 429 });
  const b = (await request.json().catch(() => ({}))) as { key?: unknown };
  const db = await getDb();
  const day = new Date().toISOString().slice(0, 10);
  const hour = Math.floor(Date.now() / 3600000);
  const { results: residents } = await db.prepare(`SELECT handle FROM residents WHERE tier <> 'admin' ORDER BY id`).all<{ handle: string }>();
  const handles = residents.map((r) => r.handle);
  const owners = houses(handles.length).map((h) => h.owner!).filter((o) => o !== undefined);
  const roster = new Set(dayRoster(day, handles.length, owners));
  const task = tasksFor(day, user.id, residentsOut(hour - (hour % 24), handles.length).filter((r) => roster.has(r.who)), handles).find((t) => t.key === b.key);
  if (!task) return Response.json({ error: 'task' }, { status: 400 });
  const ins = await db.prepare(`INSERT OR IGNORE INTO goose_tasks (user_id, day, key) VALUES (?, ?, ?)`).bind(user.id, day, task.key).run();
  if (!ins.meta.changes) return Response.json({ ok: true, already: true });
  await db.prepare(`INSERT INTO pond_players (user_id, coins) VALUES (?1, ?2) ON CONFLICT(user_id) DO UPDATE SET coins = coins + ?2`).bind(user.id, task.coins).run();
  const [today, total] = await Promise.all([
    db.prepare(`SELECT COUNT(*) AS n FROM goose_tasks WHERE user_id = ? AND day = ?`).bind(user.id, day).first<{ n: number }>(),
    db.prepare(`SELECT COUNT(*) AS n FROM goose_tasks WHERE user_id = ?`).bind(user.id).first<{ n: number }>(),
  ]);
  const want = ['g:first']; if ((today?.n ?? 0) >= 8) want.push('g:day'); if ((total?.n ?? 0) >= 50) want.push('g:fifty');
  await db.batch(want.map((k) => db.prepare(`INSERT OR IGNORE INTO badges (user_id, key) VALUES (?, ?)`).bind(user.id, k)));
  return Response.json({ ok: true, coins: task.coins, today: today?.n ?? 0 });
}
