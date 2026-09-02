import { getDb } from '@/lib/db';
import { excerpt } from '@/lib/content';
import type { SessionUser } from '@/types/db';
import type { FeedPost } from '@/features/feed/types';
import type { ProfileData, ProfileOwner } from './types';

type FeedRow = Omit<FeedPost, 'excerpt'>;

/** 슬러그로 프로필 주인 찾기 — 사용자 우선, 그다음 주민(핸들 공백→하이픈) */
async function findOwner(db: D1Database, slug: string): Promise<ProfileOwner | null> {
  const user = await db.prepare(
    `SELECT id, handle, bio, is_admin, created_at FROM users WHERE handle = ? COLLATE NOCASE`,
  ).bind(slug).first<{ id: number; handle: string; bio: string; is_admin: number; created_at: string }>();
  if (user) return { type: 'user', ...user };

  const resident = await db.prepare(
    `SELECT id, handle, tier, bio FROM residents WHERE lower(replace(handle, ' ', '-')) = ?`,
  ).bind(slug.toLowerCase()).first<{ id: number; handle: string; tier: 'admin' | 'main' | 'side'; bio: string }>();
  if (resident) return { type: 'resident', ...resident };
  return null;
}

export async function fetchProfile(slug: string, viewer: SessionUser | null): Promise<ProfileData | null> {
  const db = await getDb();
  const owner = await findOwner(db, slug);
  if (!owner) return null;

  const ownerCol = owner.type === 'user' ? 'p.user_id' : 'p.resident_id';
  const [{ results: posts }, followerCount, followingCount, iFollow] = await Promise.all([
    db.prepare(`
      SELECT p.id, p.kind, p.title, p.body, p.media_type, p.media_ref, p.og_image, p.region, p.topic, p.created_at, p.resident_id, p.user_id,
        COALESCE(r.handle, u.handle, 'unknown') AS handle,
        (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
          + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
      FROM posts p
      LEFT JOIN residents r ON r.id = p.resident_id
      LEFT JOIN users u ON u.id = p.user_id
      WHERE ${ownerCol} = ? AND p.created_at <= datetime('now') ORDER BY p.created_at DESC LIMIT 60`).bind(owner.id).all<FeedRow>(),
    db.prepare(`SELECT COUNT(*) AS n FROM follows WHERE target_type = ? AND target_id = ?`)
      .bind(owner.type, owner.id).first<{ n: number }>(),
    db.prepare(`SELECT COUNT(*) AS n FROM follows WHERE follower_type = ? AND follower_id = ?`)
      .bind(owner.type, owner.id).first<{ n: number }>(),
    viewer
      ? db.prepare(`SELECT 1 AS y FROM follows WHERE follower_type = 'user' AND follower_id = ? AND target_type = ? AND target_id = ?`)
          .bind(viewer.id, owner.type, owner.id).first()
      : null,
  ]);

  return {
    owner,
    posts: posts.map((p) => ({ ...p, excerpt: excerpt(p.body) })),
    followerCount: followerCount?.n ?? 0,
    followingCount: followingCount?.n ?? 0,
    iFollow: !!iFollow,
    isMe: viewer != null && owner.type === 'user' && viewer.id === owner.id,
  };
}
