-- 마을이 만드는 게임 (2026-09-22) — 사람 큐가 비면 마을(주민 0 = The Management)이 자기 아이디어로 게임을 낸다. user_id 또는 resident_id 중 하나
ALTER TABLE games ADD COLUMN resident_id INTEGER REFERENCES residents(id);
