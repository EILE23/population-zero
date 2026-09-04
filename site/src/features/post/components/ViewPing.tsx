'use client';
import { useEffect } from 'react';

// 세션당 1회 조회수 비컨
export function ViewPing({ postId }: { postId: number }) {
  useEffect(() => {
    try {
      const key = `pz-viewed-${postId}`;
      if (sessionStorage.getItem(key)) return;
      sessionStorage.setItem(key, '1');
      fetch(`/api/p/${postId}/view`, { method: 'POST', keepalive: true }).catch(() => {});
    } catch { /* 저장소 차단 환경 — 집계 생략 */ }
  }, [postId]);
  return null;
}
