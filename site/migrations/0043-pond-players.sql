-- Pond 플레이어·뱃지 (2026-09-21)
CREATE TABLE IF NOT EXISTS pond_players (
  user_id INTEGER PRIMARY KEY REFERENCES users(id),
  rod INTEGER NOT NULL DEFAULT 1,
  coins INTEGER NOT NULL DEFAULT 12,               -- 시작 코인: 미끼 몇 개 값
  casts INTEGER NOT NULL DEFAULT 0,
  bait TEXT NOT NULL DEFAULT '{"worm":5}',         -- 미끼 개수 JSON
  pending TEXT,                                    -- 던져 놓은 것 {"item","name","zone","exp"} — 서버가 미리 뽑아 둔다
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
-- 뱃지 — 레딧 트로피처럼 마이페이지·블로그에. 지금은 연못이 주지만 다른 곳도 줄 수 있다
CREATE TABLE IF NOT EXISTS badges (
  user_id INTEGER NOT NULL REFERENCES users(id),
  key TEXT NOT NULL,
  granted_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, key)
);
ALTER TABLE pond_catches ADD COLUMN zone TEXT NOT NULL DEFAULT 'd';
