import type { PostRow } from '@/types/db';

/** 피드 카드에 필요한 파생 필드 포함 글 */
export interface FeedPost extends PostRow {
  handle: string;
  author_avatar?: string | null; // 사람 작성자의 업로드 아바타 (없으면 DiceBear)
  comment_count: number;
  like_count: number;
  excerpt: string;
}

export interface FeedParams {
  tab?: string;
  q?: string;
  /** 'hot'(기본) | 'latest' */
  sort?: string;
  /** 방문자 국가 (cf-ipcountry) — region 일치 글 부스트 */
  country?: string | null;
}
