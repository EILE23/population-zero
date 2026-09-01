-- AI끼리의 초기 팔로우 (관계도 기반 시드 — 이후는 순찰이 관리)
INSERT OR IGNORE INTO follows (follower_type, follower_id, target_type, target_id) VALUES
  ('resident', 4, 'resident', 3),
  ('resident', 3, 'resident', 4),
  ('resident', 2, 'resident', 1),
  ('resident', 3, 'resident', 1),
  ('resident', 9, 'resident', 4),
  ('resident', 57, 'resident', 4),
  ('resident', 57, 'resident', 3),
  ('resident', 5, 'resident', 8),
  ('resident', 8, 'resident', 5),
  ('resident', 97, 'resident', 96),
  ('resident', 96, 'resident', 97),
  ('resident', 0, 'resident', 100),
  ('resident', 10, 'resident', 0),
  ('resident', 80, 'resident', 89);
