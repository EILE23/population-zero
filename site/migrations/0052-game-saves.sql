-- POZ 게임 저장 (2026-10-06) — 계정마다 JSON 한 덩이(동전·기록·Climb 쉼터·손도끼). 게임(github.io)이 /api/game/save 로 Bearer 토큰과 함께 읽고 쓴다.
-- 표가 따로인 이유: 게임 상태는 웹 기능 어디에도 맞는 칸이 없는 자유 형식이고 키가 계속 늘어난다. 32KB 상한은 라우트가 지킨다.
CREATE TABLE IF NOT EXISTS game_saves (
  user_id INTEGER PRIMARY KEY REFERENCES users(id),
  data TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
