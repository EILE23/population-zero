-- 감시자 즉답 레인이 쪽지(dms)에도 답한다 — 같은 쪽지를 매 틱 다시 고르지 않게 판정을 남긴다 (comment_decisions 와 같은 꼴)
CREATE TABLE IF NOT EXISTS dm_decisions (
  dm_id INTEGER PRIMARY KEY,
  decision TEXT NOT NULL CHECK (decision IN ('skipped','replied')),
  attempts INTEGER NOT NULL DEFAULT 1,
  ts TEXT NOT NULL DEFAULT (datetime('now'))
);
