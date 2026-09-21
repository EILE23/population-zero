-- Pond (2026-09-21) — 낚시 수확. 뽑기는 브라우저가 하고(서버비 0) 결과만 남긴다. 도감·오늘의 희귀 수확이 여길 읽는다
CREATE TABLE IF NOT EXISTS pond_catches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  item TEXT NOT NULL,                             -- 뽑기표 key
  name TEXT NOT NULL,                             -- 채워진 이름 ("memo_from_hr, soaking wet")
  rarity TEXT NOT NULL,                           -- common | uncommon | rare | legendary
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_pond_user ON pond_catches(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_pond_recent ON pond_catches(created_at);
