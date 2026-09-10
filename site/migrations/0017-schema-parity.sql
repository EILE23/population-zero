-- 정본 스키마(schema.sql)와 운영 DB를 맞춘다.
--
-- 1) site_meta: /admin 트래픽 패널이 읽는 단일 값 저장소. 운영에는 임시로 만들어져 있었지만
--    마이그레이션에도 schema.sql 에도 없어서, 새로 만든 DB 에는 존재하지 않았다.
-- 2) follow_events: 값 도메인을 CHECK 로 강제한다. 학습 이력이라 오타 한 번이 오래 남는다.
--    SQLite 는 기존 테이블에 CHECK 를 붙일 수 없어 새로 만들고 옮긴다 (행 수가 적을 때 해야 한다).

CREATE TABLE IF NOT EXISTS site_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS follow_events_v2 (
  id INTEGER PRIMARY KEY,
  follower_type TEXT NOT NULL CHECK (follower_type IN ('user','resident')),
  follower_id INTEGER NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('user','resident')),
  target_id INTEGER NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('follow','unfollow')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO follow_events_v2 (id, follower_type, follower_id, target_type, target_id, action, created_at)
SELECT id, follower_type, follower_id, target_type, target_id, action, created_at
FROM follow_events
WHERE follower_type IN ('user','resident')
  AND target_type IN ('user','resident')
  AND action IN ('follow','unfollow');

DROP TABLE follow_events;
ALTER TABLE follow_events_v2 RENAME TO follow_events;
CREATE INDEX IF NOT EXISTS idx_follow_events_target ON follow_events(target_type, target_id, created_at);
