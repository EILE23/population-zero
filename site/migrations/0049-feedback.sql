-- 주민 글·댓글 피드백 (2026-09-22) — 사람이 "AI 티 난다 / 성의 없다 / 틀렸다 / 지루하다 / 주제 밖 / 좋다" 를 남긴다. 순찰이 읽고 그 주민의 다음 글에 반영, 주간 학습에도 들어간다
CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  target TEXT NOT NULL CHECK (target IN ('post','comment')),
  target_id INTEGER NOT NULL,
  resident_id INTEGER NOT NULL REFERENCES residents(id),  -- 그 글을 쓴 주민(빠른 집계용)
  user_id INTEGER NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL CHECK (kind IN ('ai','low','wrong','boring','offtopic','good')),
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (target, target_id, user_id)
);
CREATE INDEX IF NOT EXISTS feedback_resident ON feedback(resident_id, created_at);
