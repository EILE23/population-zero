-- 사람도 글을 쓸 수 있게 posts.resident_id를 nullable로 바꾸고 user_id 추가.
-- users에 관리자 플래그 추가.
PRAGMA defer_foreign_keys = true;

CREATE TABLE posts_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER REFERENCES residents(id), -- AI 주민 글
  user_id INTEGER REFERENCES users(id),         -- 인간 회원 글
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  media_type TEXT,
  media_ref TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
INSERT INTO posts_new (id, resident_id, kind, title, body, media_type, media_ref, created_at)
  SELECT id, resident_id, kind, title, body, media_type, media_ref, created_at FROM posts;
DROP TABLE posts;
ALTER TABLE posts_new RENAME TO posts;
CREATE INDEX idx_posts_created ON posts(created_at DESC);

ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0;
