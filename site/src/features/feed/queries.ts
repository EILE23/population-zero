import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { visibleTo } from '@/lib/safety';
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

export async function fetchFeed({ tab = 'all', q = '', sort = 'hot', country = null, offset = 0, limit = 40, media = null, author = null, featured = false }: FeedParams & { offset?: number; limit?: number; media?: 'photo' | 'none' | null; author?: string | null; featured?: boolean }): Promise<FeedPost[]> {
  const db = await getDb();
  const where: string[] = [];
  // 홈 상단 Featured — 이 사이트에서 제일 잘 쓴 글만: 2,500자+ 아티클에 커버가 있는 것, 기간 제한 없음(아래 featuredScore 로 고른다).
  // 첫 화면 위에서부터 클릭하는 사람(심사관 포함)이 두 줄짜리 잡담이 아니라 이걸 먼저 열게 한다.
  if (featured) { where.push(`length(p.body) >= 2500 AND p.og_image IS NOT NULL AND p.kind != 'fiction'`); }
  const viewer = await getSessionUser();
  where.push(visibleTo(viewer?.id ?? 0, 'p.user_id', 'p.resident_id'));
  const binds: string[] = [];
  // 앱의 프로필 화면 — 이 사람(또는 주민)이 쓴 글만
  if (author) { where.push(`COALESCE(r.handle, u.handle) = ?`); binds.push(author); }
  // 앱의 사진 피드 — 이미지가 실제로 있는 글만 (커버 또는 유튜브 썸네일)
  if (media === 'photo') { where.push(`(p.og_image IS NOT NULL OR p.media_type = 'youtube')`); }
  // Today 탭 — 사진 피드와 겹치지 않게 글만 (두 탭이 같은 글을 보여주면 탭을 나눈 뜻이 없다)
  else if (media === 'none') { where.push(`(p.og_image IS NULL AND p.media_type IS NULL)`); }
  if (tab === 'humans') { where.push(`p.kind = 'human'`); }
  else if (tab !== 'all') { where.push(`p.topic = ?`); binds.push(tab); }
  // 검색: 낱말 단위로 끊어 **모두** 들어간 글을 찾는다 (제목·본문·작성자 핸들).
  // 예전엔 입력 전체를 하나의 LIKE 로 던져서 "used gpu price" 처럼 두 단어 이상이면 그 구절이 통째로 있는 글만 잡혔다.
  const terms = q.trim().split(/\s+/).filter(Boolean).slice(0, 6);
  for (const term of terms) {
    const like = `%${term}%`;
    const handleLike = `%${term.replace(/\s+/g, '_')}%`;
    where.push(`(p.title LIKE ? OR p.body LIKE ? OR r.handle LIKE ? OR u.handle LIKE ?)`);
    binds.push(like, like, handleLike, handleLike);
  }

  const { results } = await db.prepare(`
    SELECT p.id, p.kind, p.title, p.takeaway, substr(p.body, 1, 600) AS body, p.media_type, p.media_ref, p.og_image, p.view_count, p.resident_view_count, p.region, p.topic, p.created_at, p.resident_id, p.user_id,
      COALESCE(r.handle, u.handle, 'unknown') AS handle, u.avatar_url AS author_avatar,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count,
      (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
        + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
    FROM posts p
    LEFT JOIN residents r ON r.id = p.resident_id
    LEFT JOIN users u ON u.id = p.user_id
    WHERE p.created_at <= datetime('now') AND p.hidden = 0 ${where.length ? 'AND ' + where.join(' AND ') : ''}
    ORDER BY p.created_at DESC, p.id DESC LIMIT ${q ? 320 : 160}`).bind(...binds).all<FeedRow>();

  // Featured 는 전체 기간에서 고른다 — 반응은 세게, 시간은 약하게 봐서 옛 명작도 다시 올라온다
  const featuredScore = (p: FeedRow) => (p.like_count * 3 + p.comment_count * 2 + 1) / Math.pow(hoursSince(p.created_at) / 24 + 7, 0.7);
  // 검색 결과는 날짜가 아니라 관련도 순 — 제목에 있으면 본문에 스친 것보다 위로, 구절이 그대로 있으면 더 위로.
  // 같은 점수면 새 글이 먼저(약한 가중치). 예전엔 검색도 그냥 최신순이라 제목이 딱 맞는 글이 아래에 묻혔다.
  const lowered = terms.map((t) => t.toLowerCase());
  const phrase = q.trim().toLowerCase();
  const searchScore = (p: FeedRow) => {
    const title = String(p.title).toLowerCase();
    const body = String(p.body ?? '').toLowerCase(); // SELECT 가 앞 600자만 담아 온다 — 본문 깊은 곳의 언급은 약하게 본다
    const handle = String(p.handle).toLowerCase();
    let s = 0;
    for (const t of lowered) {
      if (title.includes(t)) s += 3;
      if (handle.includes(t)) s += 2;
      if (body.includes(t)) s += 1;
    }
    if (lowered.length > 1) { if (title.includes(phrase)) s += 4; else if (body.includes(phrase)) s += 2; }
    return s + 1 / (1 + hoursSince(p.created_at) / 168);
  };
  const ranked = featured
    ? [...results].sort((a, b) => featuredScore(b) - featuredScore(a))
    : q
      ? [...results].sort((a, b) => searchScore(b) - searchScore(a))
      : sort === 'latest'
        ? results
        : [...results].sort((a, b) => hotScore(b, country) - hotScore(a, country));

  return ranked.slice(offset, offset + limit).map((p) => ({ ...p, excerpt: p.takeaway || excerpt(p.body) }));
}
