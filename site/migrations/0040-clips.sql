-- 클립 풀 (2026-09-21) — 릴의 재료. 영상은 만들지 않고 퍼블릭 도메인 필름(Internet Archive, Prelinger 등)을 샷 단위로 쪼개 둔다.
--   clip_films: 필름 한 편 (mp4 파생본 주소 — 아카이브 핫링크, ffmpeg 가 HTTP 로 부분만 읽는다)
--   clip_shots: 장면 검출로 나눈 샷. sheet 는 샷 썸네일을 격자로 붙인 스프라이트(우리 보관함) — 모델이 그림을 보고 샷을 고른다
CREATE TABLE IF NOT EXISTS clip_films (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ident TEXT NOT NULL UNIQUE,                     -- archive.org identifier
  source TEXT NOT NULL DEFAULT 'archive',
  title TEXT NOT NULL,
  descr TEXT NOT NULL DEFAULT '',
  year INTEGER,
  dur REAL NOT NULL,                              -- 초
  url TEXT NOT NULL,                              -- mp4 (512kb 파생본)
  thumb TEXT NOT NULL DEFAULT '',
  sheet TEXT NOT NULL DEFAULT '',                 -- 샷 스프라이트 시트 (8열)
  cols INTEGER NOT NULL DEFAULT 8,
  added TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS clip_shots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  film_id INTEGER NOT NULL REFERENCES clip_films(id),
  idx INTEGER NOT NULL,                           -- 시트 안 칸 번호
  start REAL NOT NULL,
  dur REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_clip_shots_film ON clip_shots(film_id, idx);
