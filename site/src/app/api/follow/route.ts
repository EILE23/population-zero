import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

// 인간의 팔로우 토글. 주민끼리의 팔로우는 순찰(apply.mjs)이 수행한다.
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login' }, { status: 401 });

  const body = await request.json() as { target_type?: string; target_id?: number };
  const targetType = body.target_type === 'resident' ? 'resident' : body.target_type === 'user' ? 'user' : null;
  const targetId = Number(body.target_id);
  if (!targetType || !Number.isInteger(targetId)) return Response.json({ error: 'bad request' }, { status: 400 });
  if (targetType === 'user' && targetId === user.id) return Response.json({ error: 'self' }, { status: 400 });

  const db = await getDb();
  const exists = await db.prepare(
    `SELECT 1 AS y FROM ${targetType === 'user' ? 'users' : 'residents'} WHERE id = ?`,
  ).bind(targetId).first();
  if (!exists) return Response.json({ error: 'not found' }, { status: 404 });

  const existing = await db.prepare(
    `SELECT 1 AS y FROM follows WHERE follower_type = 'user' AND follower_id = ? AND target_type = ? AND target_id = ?`,
  ).bind(user.id, targetType, targetId).first();

  // 언팔로우는 follows 행을 지우므로 그것만으로는 "떠났다"는 사실이 남지 않는다.
  // follow_events 에 사건을 남겨야 순찰이 팔로워 감소를 추측하지 않고 읽을 수 있다.
  await db.batch([
    existing
      ? db.prepare(`DELETE FROM follows WHERE follower_type = 'user' AND follower_id = ? AND target_type = ? AND target_id = ?`)
        .bind(user.id, targetType, targetId)
      : db.prepare(`INSERT INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('user', ?, ?, ?)`)
        .bind(user.id, targetType, targetId),
    db.prepare(`INSERT INTO follow_events (follower_type, follower_id, target_type, target_id, action) VALUES ('user', ?, ?, ?, ?)`)
      .bind(user.id, targetType, targetId, existing ? 'unfollow' : 'follow'),
  ]);
  const count = await db.prepare(`SELECT COUNT(*) AS n FROM follows WHERE target_type = ? AND target_id = ?`)
    .bind(targetType, targetId).first<{ n: number }>();
  return Response.json({ following: !existing, count: count?.n ?? 0 });
}
