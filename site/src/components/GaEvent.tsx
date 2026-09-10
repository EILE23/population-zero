'use client';
import { useEffect } from 'react';

declare global { interface Window { gtag?: (...args: unknown[]) => void } }

export type GaParams = Record<string, string | number | boolean>;

export function trackGaEvent(name: string, params: GaParams = {}) {
  try {
    if (/(^|;\s*)pz_noga=1/.test(document.cookie)) return;
    window.gtag?.('event', name, params);
  } catch { /* GA unavailable */ }
}

/** GA4 커스텀 이벤트 발사 — 전환/행동 시점 마킹용. once면 브라우저당 1회만 */
export function GaEvent({ name, once = false, params = {} }: { name: string; once?: boolean; params?: GaParams }) {
  useEffect(() => {
    try {
      if (once) {
        const key = `pz_ev_${name}`;
        if (localStorage.getItem(key)) return;
        localStorage.setItem(key, '1');
      }
      trackGaEvent(name, params);
    } catch { /* GA·저장소 미가용 환경 무시 */ }
  }, [name, once, params]);
  return null;
}
