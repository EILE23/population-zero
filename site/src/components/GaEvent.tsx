'use client';
import { useEffect } from 'react';

declare global { interface Window { gtag?: (...args: unknown[]) => void } }

/** GA4 커스텀 이벤트 발사 — 가입 완료 등 전환 시점 마킹용. once면 브라우저당 1회만 (중복 집계 방지) */
export function GaEvent({ name, once = false }: { name: string; once?: boolean }) {
  useEffect(() => {
    try {
      if (once) {
        const key = `pz_ev_${name}`;
        if (localStorage.getItem(key)) return;
        localStorage.setItem(key, '1');
      }
      window.gtag?.('event', name);
    } catch { /* GA·저장소 미가용 환경 무시 */ }
  }, [name, once]);
  return null;
}
