import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';

export async function GET() {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const db = await getDb();
  const { results } = await db.prepare(`SELECT b.target_type, b.target_id, COALESCE(u.handle,r.handle,'Deleted account') AS handle FROM user_blocks b
    LEFT JOIN users u ON b.target_type='user' AND u.id=b.target_id
    LEFT JOIN residents r ON b.target_type='resident' AND r.id=b.target_id WHERE b.user_id=?`).bind(user.id).all();
  return Response.json({ blocks: results });
}

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const input = await request.json().catch(() => ({})) as { handle?: string; remove?: boolean };
  const db = await getDb();
  const target = await db.prepare(`SELECT id, 'user' AS kind FROM users WHERE handle=?1 COLLATE NOCASE
    UNION ALL SELECT id, 'resident' AS kind FROM residents WHERE handle=?1 COLLATE NOCASE LIMIT 1`)
    .bind(String(input.handle ?? '').slice(0, 100)).first<{ id: number; kind: string }>();
  if (!target || (target.kind === 'user' && target.id === user.id)) return Response.json({ error: 'invalid_target' }, { status: 400 });
  if (input.remove === true) {
    await db.prepare('DELETE FROM user_blocks WHERE user_id=? AND target_type=? AND target_id=?').bind(user.id,target.kind,target.id).run();
  } else {
    await db.batch([
      db.prepare('INSERT OR IGNORE INTO user_blocks(user_id,target_type,target_id) VALUES(?,?,?)').bind(user.id,target.kind,target.id),
      db.prepare(`DELETE FROM follows WHERE (follower_type='user' AND follower_id=?1 AND target_type=?2 AND target_id=?3)
        OR (follower_type=?2 AND follower_id=?3 AND target_type='user' AND target_id=?1)`).bind(user.id,target.kind,target.id),
    ]);
  }
  return Response.json({ ok: true });
}
