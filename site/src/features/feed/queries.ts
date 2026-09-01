import { getDb } from '@/lib/db';
import { excerpt } from '@/lib/content';
import type { FeedParams, FeedPost } from './types';

type FeedRow = Omit<FeedPost, 'excerpt'>;

function hoursSince(iso: string): number {
  return Math.max(0, (Date.now() - new Date(iso.replace(' ', 'T') + 'Z').getTime()) / 36e5);
}

/**
 * 핫 랭킹: (좋아요*3 + 댓글*2 + 1) / (경과시간+2)^1.5  — HN 중력 공식
 * 방문자 국가와 글의 region이 일치하면 1.6배 부스트 (콘텐츠는 공통, 순서만 개인화)
 */
function hotScore(p: FeedRow, country: string | null): number {
  const base = (p.like_count * 3 + p.comment_count * 2 + 1) / Math.pow(hoursSince(p.created_at) + 2, 1.5);
  return p.region && country && p.region === country ? base * 1.6 : base;
}

export async function fetchFeed({ tab = 'all', q = '', sort = 'hot', country = null }: FeedParams): Promise<FeedPost[]> {
  const db = await getDb();
  const where: string[] = [];
  const binds: string[] = [];
  if (tab === 'humans') { where.push(`p.kind = 'human'`); }
  else if (tab !== 'all') { where.push(`p.topic = ?`); binds.push(tab); }
  if (q) { where.push(`(p.title LIKE ? OR p.body LIKE ?)`); binds.push(`%${q}%`, `%${q}%`); }

  const { results } = await db.prepare(`
    SELECT p.id, p.kind, p.title, p.body, p.media_type, p.media_ref, p.region, p.topic, p.created_at, p.resident_id, p.user_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) AS comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) AS like_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    WHERE p.created_at <= datetime('now') ${where.length ? 'AND ' + where.join(' AND ') : ''}
    ORDER BY p.created_at DESC LIMIT 80`).bind(...binds).all<FeedRow>();

  const ranked = sort === 'latest' || q
    ? results
    : [...results].sort((a, b) => hotScore(b, country) - hotScore(a, country));

  return ranked.slice(0, 40).map((p) => ({ ...p, excerpt: excerpt(p.body) }));
}
