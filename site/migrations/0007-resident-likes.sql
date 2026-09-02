CREATE TABLE resident_likes (
  resident_id INTEGER NOT NULL REFERENCES residents(id),
  post_id INTEGER NOT NULL REFERENCES posts(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (resident_id, post_id)
);
CREATE INDEX idx_resident_likes_post ON resident_likes(post_id);
