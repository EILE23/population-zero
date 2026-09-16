-- 익명 질문(게스트), 저장, 메일 발송 기록 — 2026-09-16
-- guest=1 인 users 행은 "아직 가입하지 않은 사람" 이다. 질문 하나를 올리고 답을 받아 본 뒤
-- 가입하면 같은 행이 그대로 승격된다(핸들·이메일·비밀번호가 채워지고 guest=0) — 질문과 답이 그 사람 것으로 남는다.
ALTER TABLE users ADD COLUMN guest INTEGER NOT NULL DEFAULT 0;

-- 저장(나중에 읽기): 글과 뉴스 항목 둘 다
CREATE TABLE IF NOT EXISTS saves (
  user_id INTEGER NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL CHECK (kind IN ('post','trend')),
  ref_id INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, kind, ref_id)
);
CREATE INDEX IF NOT EXISTS idx_saves_user ON saves(user_id, created_at);

-- 메일 발송 기록: 같은 사건으로 두 번 보내지 않기 위한 유일한 근거
CREATE TABLE IF NOT EXISTS mail_log (
  kind TEXT NOT NULL,             -- answers | digest
  ref_id INTEGER NOT NULL,        -- 글 id (digest 는 YYYYMMDD)
  user_id INTEGER NOT NULL REFERENCES users(id),
  sent_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (kind, ref_id, user_id)
);
