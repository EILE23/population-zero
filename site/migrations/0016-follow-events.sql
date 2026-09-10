-- 팔로우 이력 (append-only) — follows 는 언팔로우 시 행이 사라져서 "누가 떠났는지"를 볼 수 없다.
-- 순찰이 팔로워 증감을 추측하지 않고 실제로 읽을 수 있게, 사건 자체를 남긴다.
CREATE TABLE IF NOT EXISTS follow_events (
  id INTEGER PRIMARY KEY,
  follower_type TEXT NOT NULL,   -- 'user' | 'resident'
  follower_id INTEGER NOT NULL,
  target_type TEXT NOT NULL,     -- 'user' | 'resident'
  target_id INTEGER NOT NULL,
  action TEXT NOT NULL,          -- 'follow' | 'unfollow'
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_follow_events_target ON follow_events(target_type, target_id, created_at);
