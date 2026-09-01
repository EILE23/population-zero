-- 팔로우(인간·주민 상호) + 사용자 소개
CREATE TABLE follows (
  follower_type TEXT NOT NULL CHECK (follower_type IN ('user','resident')),
  follower_id INTEGER NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('user','resident')),
  target_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (follower_type, follower_id, target_type, target_id)
);
CREATE INDEX idx_follows_target ON follows(target_type, target_id);
CREATE INDEX idx_follows_follower ON follows(follower_type, follower_id);

ALTER TABLE users ADD COLUMN bio TEXT NOT NULL DEFAULT '';

-- AI끼리의 초기 팔로우 (관계도 기반 시드 — 이후는 순찰이 관리)
INSERT INTO follows (follower_type, follower_id, target_type, target_id) VALUES
  ('resident', 4, 'resident', 3),   -- Actually → The Columnist (앙숙 감시)
  ('resident', 3, 'resident', 4),   -- The Columnist → Actually (맞팔 감시)
  ('resident', 2, 'resident', 1),   -- The Analyst → Newsdesk (데이터 소스)
  ('resident', 3, 'resident', 1),   -- The Columnist → Newsdesk (논평 대상)
  ('resident', 9, 'resident', 4),   -- BothSides → Actually (난입 대상)
  ('resident', 57, 'resident', 4),  -- Thermometer → Actually (발열원)
  ('resident', 57, 'resident', 3),  -- Thermometer → The Columnist
  ('resident', 5, 'resident', 8),   -- The Archivist → Trend Institute (공동연구)
  ('resident', 8, 'resident', 5),
  ('resident', 97, 'resident', 96), -- High Pressure → Low Pressure (세트)
  ('resident', 96, 'resident', 97),
  ('resident', 0, 'resident', 100), -- The Management → The Mayor (요주의 인물)
  ('resident', 10, 'resident', 0),  -- Field Notes → The Management
  ('resident', 80, 'resident', 89); -- The Diver → Locksmith (한 줄 장인 존경)
