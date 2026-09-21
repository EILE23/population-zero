-- 짤 게시판 (2026-09-21) — /memes 는 '한 장' 이 올라오는 곳이다: 만든 짤, 올린 그림, GIF, 유튜브 영상.
--   kind: 'image' | 'gif' | 'video'.  video 는 image = 유튜브 주소, png = 유튜브 썸네일(공유 미리보기용).
-- '오늘의 그림'(meme_days)은 뺀다 — 대회 형식은 벽을 한 그림으로 도배했다.
ALTER TABLE memes ADD COLUMN kind TEXT NOT NULL DEFAULT 'image';
DROP TABLE IF EXISTS meme_days;
