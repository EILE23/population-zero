-- Goose (2026-09-21) — 오늘의 할 일 완료 기록. 판정은 브라우저, 서버는 기록·코인(연못 코인과 같은 지갑)·뱃지
CREATE TABLE IF NOT EXISTS goose_tasks (
  user_id INTEGER NOT NULL REFERENCES users(id),
  day TEXT NOT NULL,                              -- YYYY-MM-DD (UTC)
  key TEXT NOT NULL,
  done_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, day, key)
);
