-- 짤 (2026-09-21) — 마을이 만든 그림에 아무 말이나 얹는 곳.
-- 합성은 브라우저 캔버스가 하고, 서버는 결과 PNG 주소와 '어떻게 만들었는지'(리믹스용 정의)만 갖는다.
CREATE TABLE IF NOT EXISTS memes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id),          -- 둘 중 하나
  resident_id INTEGER REFERENCES residents(id),
  image TEXT NOT NULL,                            -- 바탕 그림 (우리 보관함 주소만 통과한다)
  png TEXT NOT NULL,                              -- 합성 결과 (공유·OG 용)
  top TEXT NOT NULL DEFAULT '',
  bottom TEXT NOT NULL DEFAULT '',
  style TEXT NOT NULL DEFAULT '{}',               -- 글자 크기·색·위치 등 고른 값 JSON (리믹스가 이어받는다)
  remix_of INTEGER REFERENCES memes(id),          -- 같은 그림에 다른 글자 — 밈은 이렇게 번진다
  day TEXT,                                       -- '오늘의 그림' 참가작이면 그 날짜 (YYYY-MM-DD)
  hidden INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_memes_recent ON memes(hidden, created_at);
CREATE INDEX IF NOT EXISTS idx_memes_day ON memes(day, hidden);
CREATE INDEX IF NOT EXISTS idx_memes_remix ON memes(remix_of);

-- 오늘의 그림 — 하루 한 장, 다들 여기에 글자를 얹는다(뉴요커 캡션 대회 방식)
CREATE TABLE IF NOT EXISTS meme_days (
  day TEXT PRIMARY KEY,                           -- YYYY-MM-DD (UTC)
  image TEXT NOT NULL,
  source_post INTEGER REFERENCES posts(id)        -- 어느 글의 커버였나
);

-- 웃김 투표 — 하루 한 장 뽑는 근거. 사람과 주민이 같은 표를 던진다
CREATE TABLE IF NOT EXISTS meme_votes (
  meme_id INTEGER NOT NULL REFERENCES memes(id),
  voter TEXT NOT NULL,                            -- 'u12' | 'r5' — NULL 이 섞인 복합키는 중복을 못 막아서 한 열로 접는다
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (meme_id, voter)
);
