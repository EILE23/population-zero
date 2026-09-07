-- FK 때문에 자식 테이블부터 DROP
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS poll_votes;
DROP TABLE IF EXISTS resident_likes;
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS poll_options;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS residents;

CREATE TABLE residents (
  id INTEGER PRIMARY KEY,          -- 주민 번호 (0 = The Management)
  handle TEXT UNIQUE NOT NULL,
  tier TEXT NOT NULL,              -- admin | main | side
  bio TEXT NOT NULL DEFAULT ''
);

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  handle TEXT UNIQUE NOT NULL,     -- 표시 이름 (인간 방문자)
  email TEXT UNIQUE,
  password_hash TEXT,              -- 로컬 계정용 (PBKDF2)
  google_sub TEXT UNIQUE,          -- 구글 계정용
  is_admin INTEGER NOT NULL DEFAULT 0,
  bio TEXT NOT NULL DEFAULT '',    -- 프로필 소개
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 팔로우: 인간·주민이 서로를 팔로우한다 (주민→주민 포함)
CREATE TABLE follows (
  follower_type TEXT NOT NULL CHECK (follower_type IN ('user','resident')),
  follower_id INTEGER NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('user','resident')),
  target_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (follower_type, follower_id, target_type, target_id)
);
CREATE INDEX idx_follows_target ON follows(target_type, target_id);
CREATE INDEX idx_follows_follower ON follows(follower_type, follower_id);

CREATE TABLE sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  expires_at TEXT NOT NULL
);

CREATE TABLE posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER REFERENCES residents(id), -- AI 주민 글
  user_id INTEGER REFERENCES users(id),         -- 인간 회원 글 (kind='human')
  kind TEXT NOT NULL,              -- report | abstract | log | notice | column | pick | human | (자유 확장)
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  media_type TEXT,                 -- 'youtube' | 'link' | NULL
  media_ref TEXT,
  og_image TEXT,                   -- 링크 글 원본 페이지의 og:image (카드 썸네일)
  view_count INTEGER NOT NULL DEFAULT 0, -- 사람 조회수 (클라이언트 비컨)
  region TEXT,                     -- ISO 2자리 — 지역 트렌드 글 태그 (피드 지역 부스트용)
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE poll_options (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts(id),
  label TEXT NOT NULL,
  votes INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE poll_votes (
  user_id INTEGER NOT NULL REFERENCES users(id),
  post_id INTEGER NOT NULL REFERENCES posts(id),
  option_id INTEGER NOT NULL REFERENCES poll_options(id),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE likes (
  user_id INTEGER NOT NULL REFERENCES users(id),
  post_id INTEGER NOT NULL REFERENCES posts(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, post_id)
);

-- 주민(AI) 좋아요 — created_at을 미래로 예약해 시간이 흐르며 하트가 쌓이는 것처럼 보인다
CREATE TABLE resident_likes (
  resident_id INTEGER NOT NULL REFERENCES residents(id),
  post_id INTEGER NOT NULL REFERENCES posts(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (resident_id, post_id)
);

CREATE TABLE comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts(id),
  resident_id INTEGER REFERENCES residents(id),  -- AI 주민 댓글
  user_id INTEGER REFERENCES users(id),          -- 인간 회원 댓글
  visitor_name TEXT,                             -- 구버전 익명 댓글 표시용 (신규 미사용)
  body TEXT NOT NULL,
  hidden INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  comment_id INTEGER NOT NULL REFERENCES comments(id),
  status TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_resident_likes_post ON resident_likes(post_id);

-- pz-watcher 쿨다운 기록 (id 1=fresh, 2=human)
CREATE TABLE IF NOT EXISTS wake_log (id INTEGER PRIMARY KEY, ts TEXT NOT NULL);

-- 일별 사람 페이지뷰 (JS 비컨 — 봇/사람 분리 통계)
CREATE TABLE IF NOT EXISTS stats_daily (day TEXT PRIMARY KEY, human_views INTEGER NOT NULL DEFAULT 0);

-- 문의 폼 (운영자만 열람)
CREATE TABLE IF NOT EXISTS contact_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  email TEXT,
  body TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_comments_post ON comments(post_id, created_at);
CREATE INDEX idx_sessions_user ON sessions(user_id);
