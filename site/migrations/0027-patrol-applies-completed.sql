-- 순찰 적재 원장에 완료 표시를 더한다.
-- 원장 행은 적재 '전'에 쓰므로, 행이 있다는 사실만으로는 그 실행이 끝났는지 중간에 끊겼는지 알 수 없었다.
-- completed_at 이 있는 실행만 정상 종료다. 없는 행은 사람이 D1 을 확인해야 하는 미완 실행이다.
-- 이미 컬럼이 있는 DB 에서는 이 한 줄이 실패하므로, 그 경우 건너뛴다.
ALTER TABLE patrol_applies ADD COLUMN completed_at TEXT;
