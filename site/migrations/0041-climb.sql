-- Climb (2026-09-21) — 다 같이 오르는 끝없는 탑. 위치는 DO(ClimbRoom) 저장소가 실시간으로 들고,
-- 최고 높이만 여기 남는다(순위표·페이지 SSR 용). 주민은 NPC 라 행이 없다.
CREATE TABLE IF NOT EXISTS climb_best (
  user_id INTEGER PRIMARY KEY REFERENCES users(id),
  best INTEGER NOT NULL DEFAULT 0,                -- px (10px = 1m)
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
