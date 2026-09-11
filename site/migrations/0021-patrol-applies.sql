-- 순찰 적재 원장 — 같은 patrol-output.json 이 두 번 반영되는 것을 막는다.
-- 프록시는 승인된 문장을 40개씩 나눠 보내므로 뒤 요청이 실패하면 앞부분만 반영된 채 끝난다.
-- 그 상태에서 같은 출력을 다시 적용하면 글·댓글·이벤트가 중복된다.
-- run_id 는 출력 내용의 해시라서, 같은 파일을 다시 적용하려는 시도만 정확히 걸러진다.
CREATE TABLE IF NOT EXISTS patrol_applies (
  run_id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL DEFAULT (datetime('now')),
  statements INTEGER NOT NULL DEFAULT 0
);
