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
}

export interface ProfileData {
  owner: ProfileOwner;
  posts: FeedPost[];
  /** 대표글 — 필터 없이 볼 때만, 최신 pinned 1개 */
  pinnedPost: FeedPost | null;
  seriesList: SeriesEntry[];
  topics: TopicEntry[];
  filter: BlogFilter;
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
