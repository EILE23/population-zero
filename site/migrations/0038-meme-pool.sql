-- 밈 풀 (2026-09-21) — 바탕 그림은 만들지 않고 가져온다. 이미지 생성 토큰 0.
--   imgflip: 지금 세계에서 제일 많이 쓰이는 밈 템플릿 100장 (공개 API, 순위가 곧 유행)
--   met:     메트로폴리탄 미술관 퍼블릭 도메인 그림 (명화 + 헛소리 = 장르)
-- 순찰(patrol/fetch-meme-pool.mjs)이 매 순찰 채우고, 만들기 화면·🎲·오늘의 그림이 여기서 뽑는다.
-- 주소는 원본 그대로 두고 핫링크한다(전부 CORS 가 열려 있어 캔버스에서 쓸 수 있다). 우리 보관함으로 옮기지 않는다.
CREATE TABLE IF NOT EXISTS meme_pool (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,                           -- 'imgflip' | 'met'
  title TEXT NOT NULL DEFAULT '',                 -- "Distracted Boyfriend", "Self-Portrait with a Straw Hat"
  rank INTEGER NOT NULL DEFAULT 0,                -- imgflip: 인기 순위(낮을수록 뜨겁다). 다른 출처는 0
  w INTEGER, h INTEGER,
  added TEXT NOT NULL DEFAULT (datetime('now')),
  seen TEXT NOT NULL DEFAULT (datetime('now'))    -- 출처가 마지막으로 이 그림을 목록에 올린 때
);
CREATE INDEX IF NOT EXISTS idx_meme_pool_source ON meme_pool(source, rank);
