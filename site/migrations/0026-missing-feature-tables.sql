-- schema.sql 에만 있고 증분 경로가 없던 기능 테이블들 — 기존 DB 를 마이그레이션만으로 올릴 수 있게 한다.
-- trends/dms/room_messages/trend_events 는 운영 DB 에 수동으로 만들어졌을 뿐 어떤 마이그레이션도 만들지 않았다.
-- 그래서 0024(dm_images)는 존재 경로가 없는 dms 를 참조했고, 새 DB 를 migration 만으로 세우면 뉴스·쪽지·채팅이 깨졌다.
-- 모두 IF NOT EXISTS 라 이미 있는 운영 DB 에서도 안전하다. 기존 데이터는 건드리지 않는다.

CREATE TABLE IF NOT EXISTS trends (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL,
  kind TEXT NOT NULL,
  region TEXT,
  lang TEXT NOT NULL DEFAULT 'en',
  topic TEXT,
  title TEXT NOT NULL,
  summary TEXT,
  source_name TEXT,
  url TEXT,
  image TEXT,
  score INTEGER NOT NULL DEFAULT 0,
  rank INTEGER NOT NULL DEFAULT 0,
  collected_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_trends_key ON trends(source, title);
CREATE INDEX IF NOT EXISTS idx_trends_region ON trends(region, collected_at);

CREATE TABLE IF NOT EXISTS dms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  thread TEXT NOT NULL,
  from_user_id INTEGER REFERENCES users(id),
  from_resident_id INTEGER REFERENCES residents(id),
  to_user_id INTEGER REFERENCES users(id),
  to_resident_id INTEGER REFERENCES residents(id),
  body TEXT NOT NULL,
  image TEXT,
  read_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_dms_thread ON dms(thread, id);
CREATE INDEX IF NOT EXISTS idx_dms_to_user ON dms(to_user_id, read_at);
CREATE INDEX IF NOT EXISTS idx_dms_to_resident ON dms(to_resident_id, id);

CREATE TABLE IF NOT EXISTS room_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  room TEXT NOT NULL,
  user_id INTEGER REFERENCES users(id),
  resident_id INTEGER REFERENCES residents(id),
  body TEXT NOT NULL,
  hidden INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_room_messages_room ON room_messages(room, id);

CREATE TABLE IF NOT EXISTS trend_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id),
  anon TEXT,
  trend_id INTEGER,
  action TEXT NOT NULL,
  topic TEXT,
  source TEXT,
  kind TEXT,
  region TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_trend_events_user ON trend_events(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_trend_events_anon ON trend_events(anon, created_at);
