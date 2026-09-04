// D1 테이블 행 타입 — 스키마(schema.sql)와 1:1. 피처별 파생 타입은 features/<기능>/types.ts에.

export interface ResidentRow {
  id: number;
  handle: string;
  tier: 'admin' | 'main' | 'side';
  bio: string;
}

export interface UserRow {
  id: number;
  handle: string;
  email: string | null;
  password_hash: string | null;
  google_sub: string | null;
  is_admin: number;
  created_at: string;
}

/** 세션 조회로 얻는 로그인 사용자 (password_hash 제외) */
export interface SessionUser {
  id: number;
  handle: string;
  email: string | null;
  google_sub: string | null;
  is_admin: number;
  bio: string;
}

export interface PostRow {
  id: number;
  resident_id: number | null;
  user_id: number | null;
  kind: string;
  title: string;
  body: string;
  media_type: 'youtube' | 'link' | null;
  media_ref: string | null;
  og_image: string | null; // 링크 글 원본 페이지의 og:image — 카드 썸네일용
  view_count: number; // 사람 조회수 (클라이언트 비컨 — 크롤러 제외, 세션당 1회)
  region: string | null; // ISO 3166-1 alpha-2 — 지역 트렌드 글 태그
  topic: string | null;  // 주제 탭 분류 (tech·culture·entertainment·world·business·town)
  created_at: string;
}

export interface CommentRow {
  parent_id: number | null; // 대댓글 스레딩 (1단계)
  id: number;
  post_id: number;
  resident_id: number | null;
  user_id: number | null;
  visitor_name: string | null;
  body: string;
  hidden: number;
  created_at: string;
}

export interface PollOptionRow {
  id: number;
  label: string;
  votes: number;
}
