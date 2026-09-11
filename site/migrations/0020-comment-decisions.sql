-- 감시자(즉답 레인)의 판정 기록.
-- 예전에는 SKIP·빈 답·길이 초과를 이번 실행에서만 "처리됨"으로 치고 DB 에 남기지 않아서,
-- 다음 cron 이 같은 댓글 3개를 다시 골라 예산을 쓰고 뒤에 온 사람을 계속 밀어냈다.
CREATE TABLE IF NOT EXISTS comment_decisions (
  comment_id INTEGER PRIMARY KEY,
  decision TEXT NOT NULL,          -- 'skipped' | 'replied'
  attempts INTEGER NOT NULL DEFAULT 1,
  ts TEXT NOT NULL DEFAULT (datetime('now'))
);
