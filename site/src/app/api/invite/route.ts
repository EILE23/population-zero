import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { isBlocked, sameOriginOrBearer } from '@/lib/safety';

/**
 * 놀이터 초대 — 로그인한 사람이 다른 사람을 게임으로 부른다. 받는 쪽은 알림에서 보고 링크를 누르면 부른 사람 옆에서 시작한다(수락 절차 없음).
 * GET: 누구를 부를 수 있나(내가 팔로우하는 사람 + 최근에 나를 부른 사람).
 * POST { to: handle, game, note }: 10분 안에 같은 사람·같은 게임으로는 한 번만. 차단한 사이에는 가지 않는다.
 */
const GAMES = /^[a-z0-9-]{3,24}$/;

export async function GET() {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ people: [] });
  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT u.handle, u.avatar_url AS avatar FROM follows f JOIN users u ON u.id = f.target_id
    WHERE f.follower_type = 'user' AND f.follower_id = ?1 AND f.target_type = 'user' AND u.guest = 0
    UNION
    SELECT u.handle, u.avatar_url AS avatar FROM invites i JOIN users u ON u.id = i.from_user_id
    WHERE i.to_user_id = ?1 AND i.created_at > datetime('now', '-14 days')
    LIMIT 40`).bind(user.id).all<{ handle: string; avatar: string | null }>();
  return Response.json({ people: results }, { headers: { 'cache-control': 'no-store' } });
}

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to invite someone.' }, { status: 401 });
  if (await rateLimited(request, 'invite', 30, 60)) return Response.json({ error: 'rate', message: 'That is enough invitations for now.' }, { status: 429 });
  const b = (await request.json().catch(() => ({}))) as { to?: unknown; game?: unknown; note?: unknown };
  const handle = String(b.to ?? '').trim().replace(/^@/, '');
  const game = String(b.game ?? 'square');
  if (!handle || !GAMES.test(game)) return Response.json({ error: 'bad' }, { status: 400 });
  const note = String(b.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);
  const db = await getDb();
  const to = await db.prepare(`SELECT id, guest FROM users WHERE handle = ? COLLATE NOCASE`).bind(handle).first<{ id: number; guest: number }>();
  if (!to || to.guest) return Response.json({ error: 'missing', message: 'No one here by that name.' }, { status: 404 });
  if (to.id === user.id) return Response.json({ error: 'self', message: 'You are already here.' }, { status: 400 });
  if (await isBlocked(user.id, { kind: 'user', id: to.id }) || await isBlocked(to.id, { kind: 'user', id: user.id })) {
    return Response.json({ error: 'blocked', message: 'Cannot invite them.' }, { status: 403 });
  }
  const recent = await db.prepare(`SELECT 1 FROM invites WHERE from_user_id = ? AND to_user_id = ? AND game = ? AND created_at > datetime('now', '-10 minutes')`)
    .bind(user.id, to.id, game).first();
  if (recent) return Response.json({ ok: true, already: true });
  await db.prepare(`INSERT INTO invites (from_user_id, to_user_id, game, note) VALUES (?, ?, ?, ?)`).bind(user.id, to.id, game, note).run();
  return Response.json({ ok: true }, { status: 201 });
}
