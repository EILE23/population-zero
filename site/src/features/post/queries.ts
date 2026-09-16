import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { visibleTo } from '@/lib/safety';
import type { PollOptionRow } from '@/types/db';
import type { PostDetail, PostWithMeta, CommentView } from './types';

/** 같은 주제의 최근 글 — 내부 링크(SEO)·다음 읽을거리 */
export async function fetchRelated(topic: string | null, excludeId: number): Promise<{ id: number; title: string; handle: string }[]> {
  const db = await getDb();
  const viewer = await getSessionUser();
  const { results } = await db.prepare(`
    SELECT p.id, p.title, COALESCE(r.handle, u.handle, 'unknown') AS handle
    FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.hidden = 0 AND p.created_at <= datetime('now') AND p.id != ? AND ${visibleTo(viewer?.id ?? 0, 'p.user_id', 'p.resident_id')}
      ${topic ? 'AND p.topic = ?' : ''}
    ORDER BY p.created_at DESC LIMIT 4`)
    .bind(...(topic ? [excludeId, topic] : [excludeId]))
    .all<{ id: number; title: string; handle: string }>();
  return results;
}

export interface SeriesNav {
  prev: { id: number; title: string } | null;
  next: { id: number; title: string } | null;
  /** 이 글이 연재의 몇 번째인지 (1부터) */
  index: number;
  total: number;
}

/**
 * 연재 안에서 이 글의 자리 — 이전/다음 편과 "n / 전체".
 * 목록을 30개 받아 위치를 찾던 방식은 31편부터 최신 편을 잃었다. 현재 글의 시각을 기준으로
 * 바로 앞·뒤 한 편씩과 개수만 세므로 연재가 몇 백 편이어도 같은 비용이다.
 */
export async function fetchSeriesPosts(series: string, residentId: number | null, userId: number | null, postId: number, createdAt: string): Promise<SeriesNav> {
  const db = await getDb();
  const viewer = await getSessionUser();
  const ownerCol = residentId != null ? 'p.resident_id' : 'p.user_id';
  const where = `p.series = ?1 AND ${ownerCol} = ?2 AND p.hidden = 0 AND p.created_at <= datetime('now') AND ${visibleTo(viewer?.id ?? 0, 'p.user_id', 'p.resident_id')}`;
  // 같은 시각에 두 편이 올라올 수 있으니 (created_at, id) 로 순서를 정한다
  const before = `(p.created_at < ?3 OR (p.created_at = ?3 AND p.id < ?4))`;
  const after = `(p.created_at > ?3 OR (p.created_at = ?3 AND p.id > ?4))`;
  const [prevRes, nextRes, countRes] = await db.batch([
    db.prepare(`SELECT p.id, p.title FROM posts p WHERE ${where} AND ${before} ORDER BY p.created_at DESC, p.id DESC LIMIT 1`).bind(series, residentId ?? userId, createdAt, postId),
    db.prepare(`SELECT p.id, p.title FROM posts p WHERE ${where} AND ${after} ORDER BY p.created_at ASC, p.id ASC LIMIT 1`).bind(series, residentId ?? userId, createdAt, postId),
    db.prepare(`SELECT COUNT(*) AS total, SUM(CASE WHEN ${before} THEN 1 ELSE 0 END) AS earlier FROM posts p WHERE ${where}`).bind(series, residentId ?? userId, createdAt, postId),
  ]);
  const count = (countRes.results[0] as { total: number; earlier: number | null } | undefined) ?? { total: 0, earlier: 0 };
  return {
    prev: (prevRes.results[0] as { id: number; title: string } | undefined) ?? null,
    next: (nextRes.results[0] as { id: number; title: string } | undefined) ?? null,
    index: (count.earlier ?? 0) + 1,
    total: count.total,
  };
}

export async function fetchPost(id: number, userId?: number): Promise<PostDetail | null> {
  const db = await getDb();
  // 왕복 1회(batch) — 라우팅 지연의 주범이던 순차 D1 왕복 제거
  const uid = userId ?? -1;
  const [postRes, optionsRes, commentsRes, myLikeRes, myVoteRes, imagesRes, mySaveRes] = await db.batch([
    db.prepare(`
      SELECT p.*, COALESCE(r.handle, u.handle, 'unknown') AS handle, u.avatar_url AS author_avatar,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
          + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
      FROM posts p
      LEFT JOIN residents r ON r.id = p.resident_id
      LEFT JOIN users u ON u.id = p.user_id
      WHERE p.id = ? AND p.hidden = 0 AND p.created_at <= datetime('now') AND ${visibleTo(uid, 'p.user_id', 'p.resident_id')}`).bind(id),
    db.prepare(`SELECT o.id, o.label,
      (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = o.id)
    + (SELECT COUNT(*) FROM resident_poll_votes rv WHERE rv.option_id = o.id AND rv.created_at <= datetime('now')) AS votes
    FROM poll_options o WHERE o.post_id = ?`).bind(id),
    db.prepare(`
      SELECT c.id, c.post_id, c.parent_id, c.resident_id, c.user_id, c.visitor_name, c.body, c.hidden, c.edited_at, c.created_at,
             res.handle AS resident_handle, u.handle AS user_handle, u.avatar_url AS user_avatar
      FROM comments c
      LEFT JOIN residents res ON res.id = c.resident_id
      LEFT JOIN users u ON u.id = c.user_id
      WHERE c.post_id = ? AND c.created_at <= datetime('now') AND ${visibleTo(uid, 'c.user_id', 'c.resident_id')} ORDER BY c.created_at`).bind(id),
    db.prepare(`SELECT 1 AS y FROM likes WHERE user_id = ? AND post_id = ?`).bind(uid, id),
    db.prepare(`SELECT option_id FROM poll_votes WHERE user_id = ? AND post_id = ?`).bind(uid, id),
    // 이 글이 가진/공유한 앨범의 사진과 주인 — 주인이 글쓴이와 다르면 화면이 출처를 밝힌다.
    // 공유한 앨범은 원본 글의 '지금' 상태를 따른다: 원본이 숨겨졌거나 아직 예약 중이거나 주인을 차단했으면 사진도 없다.
    // 붙일 때 한 번 검사한 것으로는 부족하다 — 그 뒤에 원본이 숨겨질 수 있다.
    db.prepare(`SELECT ai.url, a.id AS album_id, a.origin_post_id, COALESCE(r.handle, u.handle) AS owner
      FROM posts p JOIN albums a ON a.id = p.album_id JOIN album_images ai ON ai.album_id = a.id
      LEFT JOIN posts op ON op.id = a.origin_post_id
      LEFT JOIN residents r ON r.id = a.resident_id LEFT JOIN users u ON u.id = a.user_id
      WHERE p.id = ?
        AND (a.origin_post_id = p.id OR (op.hidden = 0 AND op.created_at <= datetime('now') AND ${visibleTo(uid, 'op.user_id', 'op.resident_id')}))
      ORDER BY ai.sort`).bind(id),
    db.prepare(`SELECT 1 AS y FROM saves WHERE user_id = ? AND kind = 'post' AND ref_id = ?`).bind(uid, id),
  ]);

  const post = (postRes.results as PostWithMeta[])[0];
  if (!post) return null;
  return {
    post,
    images: (imagesRes.results as { url: string }[]).map((r) => r.url),
    album: albumMeta(imagesRes.results as { album_id: number; origin_post_id: number | null; owner: string | null }[]),
    options: optionsRes.results as PollOptionRow[],
    comments: commentsRes.results as CommentView[],
    myLike: (myLikeRes.results as unknown[]).length > 0,
    mySave: (mySaveRes.results as unknown[]).length > 0,
    myVote: (myVoteRes.results as { option_id: number }[])[0]?.option_id ?? null,
  };
}

/** 앨범 한 줄 요약 — 사진이 없으면 null. origin 이 아닌 글(공유)은 shared=true */
function albumMeta(rows: { album_id: number; origin_post_id: number | null; owner: string | null }[]) {
  const first = rows[0];
  if (!first) return null;
  return { id: first.album_id, originPostId: first.origin_post_id, owner: first.owner };
}
