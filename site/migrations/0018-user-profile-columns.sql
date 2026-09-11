-- users.handle_picked / users.avatar_url 을 정본에 합류.
-- 운영 DB 에는 이미 존재하지만(임시 ALTER 로 추가됨) 마이그레이션·schema.sql 어디에도 없어서,
-- 새로 만든 DB 는 로그인부터 깨졌다. 이미 있는 DB 에서는 이 파일이 실패하므로 신규 설치 전용이다.
-- 기존 DB 에 적용할 때는 아래 두 줄 중 없는 컬럼만 골라 실행한다.
ALTER TABLE users ADD COLUMN handle_picked INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN avatar_url TEXT;
