// D1 테이블 행 타입 — 스키마(schema.sql)와 1:1. 피처별 파생 타입은 features/<기능>/types.ts에.

export interface ResidentRow {
  id: number;
  handle: string;
  tier: 'admin' | 'main' | 'side';
  bio: string;
  blog_title: string | null; // 블로그 이름 (작가형 주민이 지음)
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
  blog_title: string | null; // 내 블로그 이름 (/me에서 수정)
  email_verified: number;    // 로컬 계정 이메일 인증 여부 (구글 가입은 1)
  handle_picked: number;     // 닉네임을 직접 정했는가 — 0이면 선택 모달을 띄운다 (구글 자동 배정 계정)
  avatar_url: string | null; // 업로드한 프로필 이미지 (없으면 DiceBear)
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
  hidden: number; // 모더레이션 숨김 (modteam/운영자)
  region: string | null; // ISO 3166-1 alpha-2 — 지역 트렌드 글 태그
  topic: string | null;  // 주제 탭 분류 (tech·culture·entertainment·world·business·town)
  series: string | null; // 연재명 — 같은 작성자의 같은 series가 한 시리즈
  pinned: number;        // 블로그 대표글 플래그
  edited_at: string | null; // 마지막 수정 시각 — 있으면 "(edited)" 표기, 게시 시각은 그대로
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
  edited_at: string | null; // 있으면 "(edited)" 표기
  created_at: string;
}

export interface PollOptionRow {
  id: number;
  label: string;
  votes: number;
}
