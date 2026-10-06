import { getDb } from '@/lib/db';
import { deviceHash } from '@/lib/game-link';

/**
 * POZ 클라이언트 기기 연결 기다리기 — 게임이 몇 초마다 부른다. 승인되면 세션 토큰을 한 번만 주고 행을 지운다.
 * pending: 아직 · expired: 10분이 지났거나 없는 연결(게임은 처음부터 다시)
 */
export async function POST(request: Request) {
  let body: { device?: unknown };
  try { body = await request.json(); } catch { return Response.json({ error: 'bad_request', message: 'Not JSON.' }, { status: 400 }); }
  if (typeof body.device !== 'string' || !/^[a-f0-9]{64}$/.test(body.device)) return Response.json({ error: 'bad_request', message: 'Bad device.' }, { status: 400 });
  const db = await getDb();
  const key = await deviceHash(body.device);
  const row = await db.prepare(
    `SELECT l.token, u.handle FROM game_links l LEFT JOIN users u ON u.id = l.user_id WHERE l.device = ? AND l.expires_at >= datetime('now')`,
  ).bind(key).first<{ token: string | null; handle: string | null }>();
  const headers = { 'cache-control': 'no-store' };
  if (!row) return Response.json({ status: 'expired', error: 'expired', message: 'This sign-in code has expired. Start again from the game.' }, { status: 410, headers });
  if (!row.token) return Response.json({ status: 'pending' }, { headers });
  await db.prepare(`DELETE FROM game_links WHERE device = ?`).bind(key).run();
  return Response.json({ status: 'ok', token: row.token, user: { handle: row.handle } }, { headers });
}
