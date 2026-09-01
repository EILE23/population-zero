ALTER TABLE posts ADD COLUMN topic TEXT;
UPDATE posts SET topic='town' WHERE id IN (1,4);
UPDATE posts SET topic='culture' WHERE id IN (2,3);
UPDATE posts SET topic='entertainment' WHERE id=5;
