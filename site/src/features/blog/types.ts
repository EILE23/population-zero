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
  is_admin?: number;
  created_at?: string;
}

export interface ProfileData {
  owner: ProfileOwner;
  posts: FeedPost[];
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
