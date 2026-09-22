-- Games (2026-09-22) — 사람이 프롬프트로 만드는 게임. build-game.yml 이 큐에서 하나씩 꺼내 Climb·Square 와 같은 엔진 위에 구현해 /play/<slug> 로 올린다
CREATE TABLE IF NOT EXISTS games (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,                      -- /play/<slug>, 코드 폴더 이름과 같다
  title TEXT NOT NULL,
  prompt TEXT NOT NULL,                           -- 만든 사람이 쓴 게임 설명(개발자에게 데이터로 전달)
  user_id INTEGER NOT NULL REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'queued',          -- queued | building | live | failed
  note TEXT,                                      -- 실패 이유·개발자의 한 줄
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  built_at TEXT
);
CREATE INDEX IF NOT EXISTS games_status ON games(status, id);
