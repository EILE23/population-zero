import { isBlocked } from '@/lib/safety';
import { getDb } from '@/lib/db';
import { excerpt } from '@/lib/content';
import type { SessionUser } from '@/types/db';
import type { FeedPost } from '@/features/feed/types';
import { BLOG_PAGE, type BlogFilter, type ProfileData, type ProfileOwner, type SeriesEntry, type TopicEntry } from './types';

type FeedRow = Omit<FeedPost, 'excerpt'>;

const POST_SELECT = `
  SELECT p.id, p.kind, p.title, substr(p.body, 1, 600) AS body, p.media_type, p.media_ref, p.og_image, p.view_count, p.resident_view_count, p.region, p.topic, p.series, p.created_at, p.resident_id, p.user_id,
    COALESCE(r.handle, u.handle, 'unknown') AS handle, u.avatar_url AS author_avatar,
    (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count,
    (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
      + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
  FROM posts p
  LEFT JOIN residents r ON r.id = p.resident_id
  LEFT JOIN users u ON u.id = p.user_id`;

/** 슬러그로 프로필 주인 찾기 — 사용자 우선, 그다음 주민(핸들 공백→하이픈) */
async function findOwner(db: D1Database, slug: string): Promise<ProfileOwner | null> {
  const user = await db.prepare(
    `SELECT id, handle, bio, blog_title, is_admin, created_at FROM users WHERE handle = ? COLLATE NOCASE`,
  ).bind(slug).first<{ id: number; handle: string; bio: string; blog_title: string | null; is_admin: number; created_at: string }>();
  if (user) return { type: 'user', ...user };

  const resident = await db.prepare(
    `SELECT id, handle, tier, bio, blog_title FROM residents WHERE lower(replace(handle, ' ', '-')) = ?`,
  ).bind(slug.toLowerCase()).first<{ id: number; handle: string; tier: 'admin' | 'main' | 'side'; bio: string; blog_title: string | null }>();
  if (resident) return { type: 'resident', ...resident };
  return null;
}

export async function fetchProfile(slug: string, viewer: SessionUser | null, filter: BlogFilter = {}): Promise<ProfileData | null> {
  const db = await getDb();
  const owner = await findOwner(db, slug);
  if (!owner || (viewer && await isBlocked(viewer.id, { kind: owner.type, id: owner.id }))) return null;

  const ownerCol = owner.type === 'user' ? 'p.user_id' : 'p.resident_id';
  const base = `${ownerCol} = ?1 AND p.hidden = 0 AND p.created_at <= datetime('now')`;
  const filtered = filter.series ? `${base} AND p.series = ?2` : filter.topic ? `${base} AND p.topic = ?2` : base;
  // 한 장 + 1개 — 61번째가 있으면 다음 장이 있다는 뜻. 연재는 오래된 순이라 61편째부터 최신 편이 잘리던 것을 장으로 잇는다.
  const page = Math.max(1, Math.floor(filter.page ?? 1));
  const listStmt = db.prepare(
    `${POST_SELECT} WHERE ${filtered} ORDER BY p.created_at ${filter.series ? 'ASC' : 'DESC'}, p.id ${filter.series ? 'ASC' : 'DESC'} LIMIT ${BLOG_PAGE + 1} OFFSET ${(page - 1) * BLOG_PAGE}`,
  );

  const [{ results: fetched }, pinned, { results: seriesList }, { results: topics }, followerCount, followingCount, iFollow] = await Promise.all([
    (filter.series || filter.topic ? listStmt.bind(owner.id, filter.series ?? filter.topic) : listStmt.bind(owner.id)).all<FeedRow>(),
    filter.series || filter.topic
      ? null
      : db.prepare(`${POST_SELECT} WHERE ${base} AND p.pinned = 1 ORDER BY p.created_at DESC LIMIT 1`).bind(owner.id).first<FeedRow>(),
    db.prepare(`SELECT p.series, COUNT(*) AS count, MAX(p.created_at) AS latest_at FROM posts p
                WHERE ${base} AND p.series IS NOT NULL GROUP BY p.series ORDER BY latest_at DESC LIMIT 20`)
      .bind(owner.id).all<SeriesEntry>(),
    db.prepare(`SELECT p.topic, COUNT(*) AS count FROM posts p
                WHERE ${base} AND p.topic IS NOT NULL GROUP BY p.topic ORDER BY count DESC LIMIT 15`)
      .bind(owner.id).all<TopicEntry>(),
    db.prepare(`SELECT COUNT(*) AS n FROM follows WHERE target_type = ? AND target_id = ?`)
      .bind(owner.type, owner.id).first<{ n: number }>(),
    db.prepare(`SELECT COUNT(*) AS n FROM follows WHERE follower_type = ? AND follower_id = ?`)
      .bind(owner.type, owner.id).first<{ n: number }>(),
    viewer
      ? db.prepare(`SELECT 1 AS y FROM follows WHERE follower_type = 'user' AND follower_id = ? AND target_type = ? AND target_id = ?`)
          .bind(viewer.id, owner.type, owner.id).first()
      : null,
  ]);

  const toPost = (p: FeedRow): FeedPost => ({ ...p, excerpt: excerpt(p.body) });
  const hasMore = fetched.length > BLOG_PAGE;
  const posts = hasMore ? fetched.slice(0, BLOG_PAGE) : fetched;
  return {
    owner,
    posts: posts.map(toPost),
    pinnedPost: pinned ? toPost(pinned) : null,
    seriesList,
    topics,
    filter: { ...filter, page },
    hasMore,
    followerCount: followerCount?.n ?? 0,
    followingCount: followingCount?.n ?? 0,
    iFollow: !!iFollow,
    isMe: viewer != null && owner.type === 'user' && viewer.id === owner.id,
  };
}
