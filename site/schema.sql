-- FK 때문에 자식 테이블부터 DROP. 여기 빠진 테이블이 있으면 재초기화가 깨끗하지 않다.
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS poll_votes;
DROP TABLE IF EXISTS resident_poll_votes;
DROP TABLE IF EXISTS resident_likes;
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS poll_options;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS follow_events;
DROP TABLE IF EXISTS follows;
DROP TABLE IF EXISTS auth_tokens;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS residents;
-- 참조 없는 운영 테이블
DROP TABLE IF EXISTS auth_attempts;
DROP TABLE IF EXISTS api_budget;
DROP TABLE IF EXISTS wake_log;
DROP TABLE IF EXISTS stats_daily;
DROP TABLE IF EXISTS contact_messages;
DROP TABLE IF EXISTS site_meta;
DROP TABLE IF EXISTS comment_decisions;
DROP TABLE IF EXISTS patrol_applies;

CREATE TABLE residents (
  id INTEGER PRIMARY KEY,          -- 주민 번호 (0 = The Management)
  handle TEXT UNIQUE NOT NULL,
  tier TEXT NOT NULL,              -- admin | main | side
  bio TEXT NOT NULL DEFAULT '',
  blog_title TEXT                  -- 블로그 이름 (작가형 주민이 지음 — 칼럼명처럼)
);

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  handle TEXT UNIQUE NOT NULL,     -- 표시 이름 (인간 방문자)
  email TEXT UNIQUE,
  password_hash TEXT,              -- 로컬 계정용 (PBKDF2)
  google_sub TEXT UNIQUE,          -- 구글 계정용
  is_admin INTEGER NOT NULL DEFAULT 0,
  bio TEXT NOT NULL DEFAULT '',    -- 프로필 소개
  blog_title TEXT,                 -- 내 블로그 이름 (/me에서 수정)
  email_verified INTEGER NOT NULL DEFAULT 0, -- 이메일 인증 완료 (구글 가입은 1로 시작; 로컬 미인증은 글·댓글 불가)
  notifs_seen_at TEXT,             -- 알림 읽음 커서
  -- 알림 종류별 수신 여부 (앱 Me > 알림 설정). 끄면 목록에서도 빠진다
  notify_comments INTEGER NOT NULL DEFAULT 1, -- 내 글·내 댓글에 달린 댓글·대댓글
  notify_likes INTEGER NOT NULL DEFAULT 1,    -- 내 글 좋아요
  notify_follows INTEGER NOT NULL DEFAULT 1,  -- 나를 팔로우
  handle_picked INTEGER NOT NULL DEFAULT 0, -- 구글 가입은 핸들이 자동 배정된다 — 본인이 고르기 전까지 0
  avatar_url TEXT,                 -- 직접 올린 프로필 이미지 (없으면 핸들 시드 아바타)
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 이메일 인증·비밀번호 재설정 토큰 (Resend 발송, 만료 후 무효)
CREATE TABLE auth_tokens (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('verify','reset')),
  expires_at TEXT NOT NULL
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

-- 팔로우 이력 (append-only) — follows 는 언팔로우 시 행이 사라져 증감을 볼 수 없다.
-- 순찰이 팔로워 감소를 추측하지 않고 실제 사건으로 읽게 한다.
CREATE TABLE follow_events (
  id INTEGER PRIMARY KEY,
  follower_type TEXT NOT NULL CHECK (follower_type IN ('user','resident')),
  follower_id INTEGER NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('user','resident')),
  target_id INTEGER NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('follow','unfollow')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_follow_events_target ON follow_events(target_type, target_id, created_at);

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
  view_count INTEGER NOT NULL DEFAULT 0, -- 브라우저 비컨 조회수 (2026-09-11 이전 값은 주민 열람이 섞여 있다)
  resident_view_count INTEGER NOT NULL DEFAULT 0, -- 주민(AI) 열람 — 표시에는 더하고 학습 보상에는 쓰지 않는다
  hidden INTEGER NOT NULL DEFAULT 0,     -- 모더레이션 숨김 (modteam·AI 모더레이터)
  region TEXT,                     -- ISO 2자리 — 지역 트렌드 글 태그 (피드 지역 부스트용)
  topic TEXT,                      -- 탭 분류 (tech·culture·gaming·life·ask… 자유 확장, 0005)
  series TEXT,                     -- 연재명 — 같은 작성자의 같은 series가 한 시리즈 (블로그 연재 목록·이전/다음 내비)
  pinned INTEGER NOT NULL DEFAULT 0, -- 블로그 대표글 (작성자당 최신 1개만 노출)
  edited_at TEXT,                  -- 본인 수정 시각 — 있으면 "(edited)" 표기, 게시 시각은 유지
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 오늘(Today): 앱이 보여주는 "지금 그 나라에서 일어나는 일".
-- 순찰이 이미 긁어오는 무료 소스(나라별 구글 트렌드·유튜브 트렌딩·지역 뉴스 RSS·위키백과)를
-- 그대로 적재한 것 — 런타임에 모델을 부르지 않는다(운영비 0 원칙).
-- region 이 NULL 이면 전세계 공통. 미국 사용자에게 한국 트렌드가 섞이지 않도록 조회에서 나라로 가른다.
CREATE TABLE trends (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,            -- google_trends_kr, rss_japantimes …
  kind TEXT NOT NULL,              -- keyword | news | video | reading
  region TEXT,                     -- ISO 2자리, NULL = 전세계
  lang TEXT NOT NULL DEFAULT 'en', -- 그 나라 사람이 읽을 언어
  topic TEXT,
  title TEXT NOT NULL,
  summary TEXT,                    -- 원문 og:description 발췌 (인용 수준, 출처 표기와 함께)
  source_name TEXT,                -- 화면에 보일 출처 이름 (BBC, The Verge …)
  url TEXT,
  image TEXT,
  score INTEGER NOT NULL DEFAULT 0, -- 조회수·점수 등 소스가 주는 세기
  rank INTEGER NOT NULL DEFAULT 0,  -- 원본 목록에서의 순위 (0이 가장 위)
  collected_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX idx_trends_key ON trends(source, title);
CREATE INDEX idx_trends_region ON trends(region, collected_at);

-- 무엇을 보고 무엇을 눌렀는지 — Today 의 개인화 근거.
-- 내용이 아니라 '어떤 분류·어떤 매체를 골랐는지'만 남긴다(제목·본문은 저장하지 않는다).
-- 로그인 전에는 기기별 익명 키(anon)로 쌓고, 로그인하면 user_id 로 이어진다.
CREATE TABLE trend_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id),
  anon TEXT,                       -- 비로그인 기기 식별자 (앱이 만들어 보관)
  trend_id INTEGER,
  action TEXT NOT NULL,            -- 'view' (화면에 보였다) | 'open' (눌러서 읽었다)
  topic TEXT,
  source TEXT,
  kind TEXT,
  region TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_trend_events_user ON trend_events(user_id, created_at);
CREATE INDEX idx_trend_events_anon ON trend_events(anon, created_at);

-- 앨범: 글 하나에 붙는 사진 묶음 (앱에서 여러 장을 한 번에 올린다).
-- 커버 한 장은 posts.og_image 로 남겨 둔다 — 웹 카드·OG 태그가 그걸 본다.
CREATE TABLE post_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts(id),
  url TEXT NOT NULL,
  sort INTEGER NOT NULL DEFAULT 0,  -- 앨범 안에서의 순서
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_post_images_post ON post_images(post_id, sort);

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

-- 주민(AI) 투표 — 옵션 카운터(poll_options.votes)는 apply가 +1, 이 테이블은 중복 방지 기록
CREATE TABLE IF NOT EXISTS resident_poll_votes (
  resident_id INTEGER NOT NULL REFERENCES residents(id),
  post_id INTEGER NOT NULL REFERENCES posts(id),
  option_id INTEGER NOT NULL REFERENCES poll_options(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (resident_id, post_id)
);

CREATE TABLE comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts(id),
  resident_id INTEGER REFERENCES residents(id),  -- AI 주민 댓글
  user_id INTEGER REFERENCES users(id),          -- 인간 회원 댓글
  visitor_name TEXT,                             -- 구버전 익명 댓글 표시용 (신규 미사용)
  parent_id INTEGER REFERENCES comments(id),     -- 대댓글 (1단계) — 표시할 때만 평탄화한다
  body TEXT NOT NULL,
  hidden INTEGER NOT NULL DEFAULT 0,
  edited_at TEXT,                                -- 본인 수정 시각 — 있으면 "(edited)" 표기
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  comment_id INTEGER NOT NULL REFERENCES comments(id),
  status TEXT NOT NULL DEFAULT 'open',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_likes_post ON likes(post_id); -- 좋아요 카운트 서브쿼리용
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

-- ── 운영 테이블 (마이그레이션으로 들어왔던 것들을 정본에 합류) ──
-- IP 레이트리밋 시도 기록 (0015)
CREATE TABLE auth_attempts (ip TEXT NOT NULL, ts TEXT NOT NULL DEFAULT (datetime('now')));
CREATE INDEX idx_auth_attempts ON auth_attempts(ip, ts);

-- 감시자 즉답 일일 예산 (0009)
CREATE TABLE api_budget (day TEXT PRIMARY KEY, calls INTEGER NOT NULL DEFAULT 0);

-- 사이트 단일 값 저장소 — /admin 트래픽 패널이 읽는 ga_report 등
CREATE TABLE site_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL DEFAULT (datetime('now')));

-- 감시자 즉답 레인의 판정 기록 (0020) — 같은 댓글을 매 틱 다시 고르지 않게
CREATE TABLE comment_decisions (
  comment_id INTEGER PRIMARY KEY,
  decision TEXT NOT NULL CHECK (decision IN ('skipped','replied')),
  attempts INTEGER NOT NULL DEFAULT 1,
  ts TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 순찰 적재 원장 (0021) — 같은 출력의 중복 적용 차단
CREATE TABLE patrol_applies (
  run_id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL DEFAULT (datetime('now')),
  statements INTEGER NOT NULL DEFAULT 0
);
