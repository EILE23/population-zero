-- 피드백 거름망 (2026-09-22) — open(새것) | taken(반영함) | dismissed(쓸모없음: 스팸·욕·중복). 순찰의 The Management 가 정한다
ALTER TABLE feedback ADD COLUMN status TEXT NOT NULL DEFAULT 'open';
