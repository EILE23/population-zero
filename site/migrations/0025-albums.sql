-- 앨범을 글에서 떼어낸다.
-- 지금까지 "사진 여러 장이 딸린 글" 이 앨범이었다(post_images). 이제 앨범은 독립 객체이고,
-- 글은 앨범을 '가진다/공유한다'(posts.album_id). 앨범이 처음 올라온 글(origin_post_id)이
-- 그 앨범의 좋아요·댓글이 쌓이는 자리다 — 반응 체계를 둘로 만들지 않기 위해.
CREATE TABLE IF NOT EXISTS albums (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id),
  resident_id INTEGER REFERENCES residents(id),
  caption TEXT NOT NULL DEFAULT '',
  origin_post_id INTEGER REFERENCES posts(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS album_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  album_id INTEGER NOT NULL REFERENCES albums(id),
  url TEXT NOT NULL,
  sort INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_album_images_album ON album_images(album_id, sort);
CREATE INDEX IF NOT EXISTS idx_albums_owner ON albums(user_id, resident_id);
ALTER TABLE posts ADD COLUMN album_id INTEGER REFERENCES albums(id);
CREATE INDEX IF NOT EXISTS idx_posts_album ON posts(album_id);

-- 기존 데이터: 사진이 딸린 글마다 앨범 하나. 그 글이 origin 이고, 그 글이 앨범을 가진다.
INSERT INTO albums (user_id, resident_id, caption, origin_post_id, created_at)
  SELECT p.user_id, p.resident_id, p.title, p.id, p.created_at
  FROM posts p WHERE EXISTS (SELECT 1 FROM post_images pi WHERE pi.post_id = p.id);
INSERT INTO album_images (album_id, url, sort)
  SELECT a.id, pi.url, pi.sort FROM post_images pi JOIN albums a ON a.origin_post_id = pi.post_id;
UPDATE posts SET album_id = (SELECT a.id FROM albums a WHERE a.origin_post_id = posts.id)
  WHERE id IN (SELECT origin_post_id FROM albums);
DROP TABLE post_images;
