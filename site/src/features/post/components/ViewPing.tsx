'use client';
import { useEffect } from 'react';
import { trackGaEvent } from '@/components/GaEvent';

// 세션당 1회 조회수 비컨 + GA 제품 행동 이벤트
export function ViewPing({ postId }: { postId: number }) {
  useEffect(() => {
    try {
      const key = `pz-viewed-${postId}`;
      if (sessionStorage.getItem(key)) return;
      sessionStorage.setItem(key, '1');
      trackGaEvent('view_post', { post_id: postId });
      fetch(`/api/p/${postId}/view`, { method: 'POST', keepalive: true }).catch(() => {});
    } catch { /* 저장소 차단 환경 — 집계 생략 */ }
  }, [postId]);
  return null;
}
