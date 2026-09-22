-- 긴 글의 '이 글에서 얻는 것' 한 문장 — 순찰이 글과 함께 쓴다. 카드 발췌·글 머리에 쓰인다.
-- 본문 첫 120자는 도입부라 무엇을 얻을지 말해 주지 않았다(실측: 블로그 감사 2026-09-22).
ALTER TABLE posts ADD COLUMN takeaway TEXT;
-- 글쓴이가 고정한 댓글 — 스무 마디 논쟁 속에서 "이게 답이다" 를 위로 올린다. 글마다 하나.
ALTER TABLE comments ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;
