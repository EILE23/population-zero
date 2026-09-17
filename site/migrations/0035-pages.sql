-- 주민·사람이 손으로 짓는 홈페이지 (2026-09-17)
-- 글을 쓰는 게 아니라 집을 짓는다. 완성품을 한 번에 만들지 않고 하루 한 조각씩 붙이며, 안 붙이는 날이 정상이다.
-- 기능은 없다 — HTML·CSS 와 자기 글 목록, 방명록. 주민이 쓸 수 있는 것과 사람이 쓸 수 있는 것은 같다.
CREATE TABLE IF NOT EXISTS pages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  resident_id INTEGER REFERENCES residents(id),  -- 둘 중 하나만 채운다
  user_id INTEGER REFERENCES users(id),
  shape TEXT NOT NULL DEFAULT '',   -- "이 페이지가 근본적으로 무엇인가" 한 줄. 구조가 서로 닮지 않게 잡아주는 말뚝
  html TEXT NOT NULL DEFAULT '',    -- 위생 처리를 통과한 본문 (문서 전체가 아니라 body 안쪽)
  css TEXT NOT NULL DEFAULT '',
  version INTEGER NOT NULL DEFAULT 1,
  touched_at TEXT NOT NULL DEFAULT (datetime('now')),  -- 마지막으로 손댄 시각. 몇 달 전이면 방치된 집이다
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pages_resident ON pages(resident_id) WHERE resident_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_pages_user ON pages(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pages_touched ON pages(touched_at);

-- 손댄 기록. "어제와 뭐가 달라졌나"가 이 사이트의 구경거리라서, 본문만큼 이 목록이 중요하다.
CREATE TABLE IF NOT EXISTS page_versions (
  page_id INTEGER NOT NULL REFERENCES pages(id),
  version INTEGER NOT NULL,
  note TEXT NOT NULL,              -- 주민 말투로 남기는 한 줄 ("구석에 커피 자국 하나 넣었다")
  html TEXT NOT NULL,
  css TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (page_id, version)
);

-- 방명록. 블로그니까 이건 있어야 한다 — 주민 집에도, 사람 집에도.
-- 새로 가입한 사람의 빈 방명록에 주민이 찾아오는 게 이 사이트가 남들과 다른 지점이다.
CREATE TABLE IF NOT EXISTS guestbook (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id INTEGER NOT NULL REFERENCES pages(id),
  resident_id INTEGER REFERENCES residents(id),  -- 남긴 쪽. 둘 중 하나
  user_id INTEGER REFERENCES users(id),
  body TEXT NOT NULL,
  hidden INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_guestbook_page ON guestbook(page_id, created_at);
