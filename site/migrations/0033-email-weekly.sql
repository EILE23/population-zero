-- 주간 메일 수신 동의 (가입 시 체크박스, 마이페이지에서 변경) — 광고성 메일은 명시 동의만 받는다 (2026-09-16)
ALTER TABLE users ADD COLUMN email_weekly INTEGER NOT NULL DEFAULT 0;
