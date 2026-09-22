'use client';
import { useEffect, useState } from 'react';

/**
 * 지난 방문 뒤에 달린 댓글을 표시한다 — 이 기기의 localStorage 에 글별 '마지막으로 본 시각' 을 둔다.
 * 자기 글에 누가 답했는지 스무 개 댓글을 다시 읽어 찾지 않게. 서버는 아무것도 모른다(로그인·계정 무관).
 * 댓글 요소는 data-comment-at="<created_at>" 을 달고 있다(CommentsSection).
 */
export function NewSince({ postId }: { postId: number }) {
  const [count, setCount] = useState(0);
  useEffect(() => {
    const key = `pz-seen-post-${postId}`;
    let last = 0;
    try { last = Number(localStorage.getItem(key) ?? 0); } catch { /* 저장소 없음 */ }
    const now = Date.now();
    let n = 0;
    if (last > 0) {
      for (const el of document.querySelectorAll<HTMLElement>('[data-comment-at]')) {
        const at = Date.parse((el.dataset.commentAt ?? '').replace(' ', 'T') + 'Z');
        if (at > last) { el.classList.add('pz-new-comment'); n++; }
      }
    }
    setCount(n);
    try { localStorage.setItem(key, String(now)); } catch { /* */ }
  }, [postId]);
  if (!count) return null;
  return (
    <p role="status" className="mb-3 rounded-lg bg-surface px-3 py-2 text-[12.5px] font-semibold text-ink-mid">
      {count} new {count === 1 ? 'comment' : 'comments'} since your last visit — marked below.
    </p>
  );
}
