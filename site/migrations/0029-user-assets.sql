-- 업로드 자산의 소유 원장 — 어떤 파일이 누구 것인지, 지금 어떤 글이 참조하든 말든 남긴다.
-- 계정 삭제는 지금까지 '현재 글·아바타·앨범이 가리키는 주소' 에서만 파일을 찾았다.
-- 글을 먼저 지우거나 아바타를 바꾼 뒤 탈퇴하면 그 파일은 어디서도 참조되지 않아 정리 큐에 0개로 들어갔다 —
-- 공개 CDN 에 남은 채로. 업로드 시점에 여기 적어 두면 참조와 무관하게 정리 대상이 된다.
CREATE TABLE IF NOT EXISTS user_assets (
  path TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_user_assets_user ON user_assets(user_id);
