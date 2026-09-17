-- 키워드 알림과 아침 브리핑 (2026-09-17)
-- 순찰이 이미 하루 8번 12개국 기사를 모아 둔다. 그 위에 "이 단어가 뜨면 알려줘"와 "아침에 한 통"을 얹는다.
-- 런타임 모델 호출 없음 — 전부 문자열 매칭과 집계다.
CREATE TABLE IF NOT EXISTS alerts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  keyword TEXT NOT NULL,                 -- 소문자로 저장한다 (매칭도 소문자끼리)
  region TEXT NOT NULL DEFAULT '',       -- '' = 모든 나라
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_alerts_key ON alerts(user_id, keyword, region);
CREATE INDEX IF NOT EXISTS idx_alerts_user ON alerts(user_id);

-- 같은 기사를 같은 알림으로 두 번 보내지 않기 위한 유일한 근거
CREATE TABLE IF NOT EXISTS alert_sent (
  alert_id INTEGER NOT NULL REFERENCES alerts(id),
  trend_id INTEGER NOT NULL,
  sent_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (alert_id, trend_id)
);

ALTER TABLE users ADD COLUMN email_brief INTEGER NOT NULL DEFAULT 0;  -- 아침 브리핑 수신
ALTER TABLE users ADD COLUMN brief_region TEXT;                        -- 브리핑 기준 나라 (NULL = 영어권 전체)
