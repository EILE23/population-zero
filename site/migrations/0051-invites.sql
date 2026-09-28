-- 놀이터 초대 (2026-09-28) — 로그인한 사람이 다른 사람을 게임으로 부른다. 받는 쪽은 알림으로 본다(팔로우·댓글과 같은 자리).
-- game: 'square' | 'climb' | 사람이 만든 게임의 slug. 수락이라는 상태는 없다 — 링크를 누르면 그 사람 옆에서 시작한다.
CREATE TABLE IF NOT EXISTS invites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_user_id INTEGER NOT NULL REFERENCES users(id),
  to_user_id INTEGER NOT NULL REFERENCES users(id),
  game TEXT NOT NULL DEFAULT 'square',
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS invites_to ON invites(to_user_id, created_at);
