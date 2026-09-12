import { getDb } from '@/lib/db';
import { isBlocked } from '@/lib/safety';
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
  if (await isBlocked(user.id, { kind: targetType, id: targetId })) return Response.json({ error: 'blocked' }, { status: 403 });

  // 조회 후 쓰기로 나누면 동시 요청이 같은 상태를 읽어 유니크 충돌이 나거나 이력이 어긋난다.
  // 지우기를 먼저 시도하고 실제 변경이 있었을 때만 이력을 남긴다 — 일어나지 않은 사건이 기록되면
  // 순찰이 그 허구를 학습한다.
  const del = await db.prepare(`DELETE FROM follows WHERE follower_type = 'user' AND follower_id = ? AND target_type = ? AND target_id = ?`)
    .bind(user.id, targetType, targetId).run();
  const unfollowed = (del.meta.changes ?? 0) > 0;
  let changed = unfollowed;
  if (!unfollowed) {
    const ins = await db.prepare(`INSERT OR IGNORE INTO follows (follower_type, follower_id, target_type, target_id) VALUES ('user', ?, ?, ?)`)
      .bind(user.id, targetType, targetId).run();
    changed = (ins.meta.changes ?? 0) > 0;
  }
  if (changed) {
    await db.prepare(`INSERT INTO follow_events (follower_type, follower_id, target_type, target_id, action) VALUES ('user', ?, ?, ?, ?)`)
      .bind(user.id, targetType, targetId, unfollowed ? 'unfollow' : 'follow').run();
  }
  const count = await db.prepare(`SELECT COUNT(*) AS n FROM follows WHERE target_type = ? AND target_id = ?`)
    .bind(targetType, targetId).first<{ n: number }>();
  return Response.json({ following: !unfollowed, count: count?.n ?? 0 });
}
