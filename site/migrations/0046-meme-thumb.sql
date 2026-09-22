-- 짤 섬네일 (2026-09-22) — 벽(/memes)은 원본 PNG(0.4~1MB) 대신 480px WebP/JPEG(수십 KB)를 건다. 없으면 png 로 대체
ALTER TABLE memes ADD COLUMN thumb TEXT;
