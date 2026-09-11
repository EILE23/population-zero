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

export async function fetchFeed({ tab = 'all', q = '', sort = 'hot', country = null, offset = 0, limit = 40, media = null, author = null }: FeedParams & { offset?: number; limit?: number; media?: 'photo' | 'none' | null; author?: string | null }): Promise<FeedPost[]> {
  const db = await getDb();
  const where: string[] = [];
  const binds: string[] = [];
  // 앱의 프로필 화면 — 이 사람(또는 주민)이 쓴 글만
  if (author) { where.push(`COALESCE(r.handle, u.handle) = ?`); binds.push(author); }
  // 앱의 사진 피드 — 이미지가 실제로 있는 글만 (커버 또는 유튜브 썸네일)
  if (media === 'photo') { where.push(`(p.og_image IS NOT NULL OR p.media_type = 'youtube')`); }
  // Today 탭 — 사진 피드와 겹치지 않게 글만 (두 탭이 같은 글을 보여주면 탭을 나눈 뜻이 없다)
  else if (media === 'none') { where.push(`(p.og_image IS NULL AND p.media_type IS NULL)`); }
  if (tab === 'humans') { where.push(`p.kind = 'human'`); }
  else if (tab !== 'all') { where.push(`p.topic = ?`); binds.push(tab); }
  // 제목·본문 + 작성자 핸들까지 검색 (예: "cant" → cant_sleep_chat 글이 잡힌다). 공백은 핸들 구분자에도 매칭되게 완화
  if (q) {
    const like = `%${q}%`;
    const handleLike = `%${q.replace(/\s+/g, '_')}%`;
    where.push(`(p.title LIKE ? OR p.body LIKE ? OR r.handle LIKE ? OR u.handle LIKE ?)`);
    binds.push(like, like, handleLike, handleLike);
  }

  const { results } = await db.prepare(`
    SELECT p.id, p.kind, p.title, substr(p.body, 1, 600) AS body, p.media_type, p.media_ref, p.og_image, p.view_count, p.resident_view_count, p.region, p.topic, p.created_at, p.resident_id, p.user_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle, u.avatar_url AS author_avatar,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    WHERE p.created_at <= datetime('now') AND p.hidden = 0 ${where.length ? 'AND ' + where.join(' AND ') : ''}
    ORDER BY p.created_at DESC LIMIT 160`).bind(...binds).all<FeedRow>();

  const ranked = sort === 'latest' || q
    ? results
    : [...results].sort((a, b) => hotScore(b, country) - hotScore(a, country));

  return ranked.slice(offset, offset + limit).map((p) => ({ ...p, excerpt: excerpt(p.body) }));
}
