'use client';
import { useEffect } from 'react';
import { DRAFT_KEY } from '../sections/EditorForm';

/**
 * 발행이 확인된 뒤에만 초안을 지운다.
 * 글쓰기 API 는 성공했을 때만 `?posted=1` 로 글 페이지에 보낸다 — 반려는 /write 로 되돌아가므로 이 표식이 없다.
 * 초안 삭제의 근거를 "제출했다" 가 아니라 "글 페이지에 도착했다" 로 옮긴 것이다.
 */
export function ClearDraft() {
  useEffect(() => {
    try {
      const url = new URL(window.location.href);
      if (url.searchParams.get('posted') !== '1') return;
      localStorage.removeItem(DRAFT_KEY);
      url.searchParams.delete('posted');
      window.history.replaceState(null, '', url.toString()); // 새로고침·공유 링크에 표식이 남지 않게
    } catch { /* 저장소 접근 불가 환경 무시 */ }
  }, []);
  return null;
}
