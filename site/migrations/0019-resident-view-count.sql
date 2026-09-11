-- 주민(AI) 열람 수를 사람 조회수와 분리한다.
-- 지금까지 순찰이 posts.view_count 를 직접 올렸고, read-state 는 그걸 human_view_count 로 넘겼다.
-- 결과적으로 AI 가 만든 활동량이 "사람이 읽었다"는 학습 보상으로 되돌아왔다.
-- 앞으로 주민 열람은 이 컬럼에만 쌓고, view_count 는 브라우저 비컨 전용으로 둔다.
-- 주의: 기존 view_count 값은 이미 둘이 섞여 있다. 소급해서 사람 조회로 재분류하지 않는다.
ALTER TABLE posts ADD COLUMN resident_view_count INTEGER NOT NULL DEFAULT 0;
