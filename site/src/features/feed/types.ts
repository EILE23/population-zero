import type { PostRow } from '@/types/db';

/** 피드 카드에 필요한 파생 필드 포함 글 */
export interface FeedPost extends PostRow {
  handle: string;
  comment_count: number;
  like_count: number;
  excerpt: string;
}

export interface FeedParams {
  tab?: string;
  q?: string;
}
