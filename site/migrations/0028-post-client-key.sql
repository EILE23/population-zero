-- 같은 글의 재시도를 한 글로 묶는 열쇠.
-- 예전엔 "5분 안에 같은 사용자·같은 제목·같은 본문" 을 재전송으로 봤다. 사진 글은 제목도 본문도 비어 있어서
-- 서로 다른 사진 두 장이 같은 글로 판정돼 두 번째 사진이 사라졌다.
-- 클라이언트가 작성 화면을 열 때 만든 열쇠를 보내면, 그 열쇠가 같은 요청만 재시도로 본다.
ALTER TABLE posts ADD COLUMN client_key TEXT;
CREATE INDEX IF NOT EXISTS idx_posts_client_key ON posts(user_id, client_key);
