import { getDb } from '@/lib/db';
import type { Party } from '@/lib/dm';

export async function isBlocked(userId: number, target: Party): Promise<boolean> {
  const db = await getDb();
  const row = await db.prepare(`SELECT 1 FROM user_blocks
    WHERE (user_id=?1 AND target_type=?2 AND target_id=?3)
       OR (?2='user' AND user_id=?3 AND target_type='user' AND target_id=?1) LIMIT 1`)
    .bind(userId, target.kind, target.id).first();
  return !!row;
}

// Only fixed application-owned column expressions may be passed here.
export function visibleTo(viewer: number, userColumn: string, residentColumn: string): string {
  if (!Number.isSafeInteger(viewer) || viewer < 1) return '1=1';
  return `NOT EXISTS (SELECT 1 FROM user_blocks ub WHERE
    (ub.user_id=${viewer} AND ((ub.target_type='user' AND ub.target_id=${userColumn}) OR (ub.target_type='resident' AND ub.target_id=${residentColumn})))
    OR (ub.target_type='user' AND ub.target_id=${viewer} AND ub.user_id=${userColumn}))`;
}

export function sameOriginOrBearer(request: Request): boolean {
  if (!request.headers.get('cookie') && request.headers.get('authorization')?.startsWith('Bearer ')) return true;
  return request.headers.get('origin') === new URL(request.url).origin;
}

export async function canSeePost(userId: number, postId: number): Promise<boolean> {
  if (!Number.isSafeInteger(postId) || postId < 1) return false;
  return !!await (await getDb()).prepare(`SELECT 1 FROM posts p WHERE p.id=? AND p.hidden=0 AND p.created_at<=datetime('now') AND ${visibleTo(userId, 'p.user_id', 'p.resident_id')}`).bind(postId).first();
}

export async function blockedHandles(userId: number): Promise<Set<string>> {
  const { results } = await (await getDb()).prepare(`SELECT COALESCE(u.handle,r.handle) AS handle FROM user_blocks b
    LEFT JOIN users u ON b.target_type='user' AND u.id=b.target_id LEFT JOIN residents r ON b.target_type='resident' AND r.id=b.target_id WHERE b.user_id=?1
    UNION SELECT u.handle FROM user_blocks b JOIN users u ON u.id=b.user_id WHERE b.target_type='user' AND b.target_id=?1`).bind(userId).all<{ handle: string }>();
  return new Set(results.map(row => row.handle));
}
