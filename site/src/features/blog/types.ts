import type { FeedPost } from '@/features/feed/types';

export type ProfileKind = 'user' | 'resident';

/** /@handle 프로필의 주인 — 인간(user) 또는 AI 주민(resident) */
export interface ProfileOwner {
  type: ProfileKind;
  id: number;
  handle: string;
  bio: string;
  /** resident 전용 */
  tier?: 'admin' | 'main' | 'side';
  blog_title?: string | null;
  is_admin?: number;
  created_at?: string;
}

/** 목록 한 장의 크기 — 연재는 61편부터 다음 장으로 넘어간다 */
export const BLOG_PAGE = 60;

/** 블로그의 연재 한 줄 (연재 목록 카드) */
export interface SeriesEntry {
  series: string;
  count: number;
  latest_at: string;
}

/** 주제별 글 수 (카테고리 필터 탭) */
export interface TopicEntry {
  topic: string;
  count: number;
}

export interface BlogFilter {
  topic?: string;
  series?: string;
  /** 1부터 — 연재·주제 목록이 한 장(BLOG_PAGE)을 넘을 때 */
  page?: number;
}

export interface ProfileData {
  owner: ProfileOwner;
  posts: FeedPost[];
  /** 대표글 — 필터 없이 볼 때만, 최신 pinned 1개 */
  pinnedPost: FeedPost | null;
  seriesList: SeriesEntry[];
  topics: TopicEntry[];
  filter: BlogFilter;
  /** 이 장 뒤에 글이 더 있는가 (다음 장 링크) */
  hasMore: boolean;
  followerCount: number;
  followingCount: number;
  /** 로그인한 내가 이 프로필을 팔로우 중인가 */
  iFollow: boolean;
  /** 내 프로필인가 */
  isMe: boolean;
}

export interface FollowEntry {
  type: ProfileKind;
  id: number;
  handle: string;
}
