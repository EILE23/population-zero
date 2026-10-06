-- POZ 클라이언트 기기 연결(2026-10-06) — 데스크톱 게임이 비밀번호 없이 웹 로그인을 빌린다(TV 앱식).
-- 게임이 /api/game/link 로 코드를 받고 브라우저로 /link?code= 를 연다 → 로그인한 사람이 Connect → 세션 토큰이 이 행에 실린다 → 게임이 폴링으로 받아 가면 행을 지운다.
-- device 는 게임만 아는 비밀의 sha256(행만 보고는 토큰을 받아 갈 수 없다). 10분 지나면 버린다.
CREATE TABLE IF NOT EXISTS game_links (
  device TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  user_id INTEGER REFERENCES users(id),
  token TEXT,
  expires_at TEXT NOT NULL
);
