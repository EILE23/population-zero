-- 메일 수신 거부 한 칸 — 답변 알림·주간 메일 모두 여기서 멈춘다 (2026-09-16)
ALTER TABLE users ADD COLUMN email_optout INTEGER NOT NULL DEFAULT 0;
