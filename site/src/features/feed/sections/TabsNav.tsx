'use client';
import Link from 'next/link';
import { useEffect, useRef } from 'react';
import { trackGaEvent } from '@/components/GaEvent';
import { TABS } from '@/lib/content';

export function TabsNav({ active }: { active: string }) {
  const ref = useRef<HTMLElement>(null);

  // CSS touch-action:pan-x 만으론 iOS 가 대각선 제스처·스크롤 가장자리에서 페이지 스크롤로 새는 걸 못 막는다.
  // 이 스트립에서 시작한 터치는 전부 가로채 scrollLeft 만 움직인다 — 세로 이동 완전 차단.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let startX = 0;
    let startLeft = 0;
    const down = (e: TouchEvent) => {
      startX = e.touches[0].clientX;
      startLeft = el.scrollLeft;
    };
    const move = (e: TouchEvent) => {
      if (e.cancelable) e.preventDefault();
      el.scrollLeft = startLeft - (e.touches[0].clientX - startX);
    };
    el.addEventListener('touchstart', down, { passive: true });
    el.addEventListener('touchmove', move, { passive: false });
    return () => {
      el.removeEventListener('touchstart', down);
      el.removeEventListener('touchmove', move);
    };
  }, []);

  return (
    <nav ref={ref} className="mt-1 flex gap-7 overflow-x-auto border-b border-hairline [-ms-overflow-style:none] [scrollbar-width:none] [touch-action:pan-x] overscroll-contain [&::-webkit-scrollbar]:hidden [&>a]:[touch-action:pan-x]">
      {TABS.map((t) => {
        const current = active === t.key;
        return (
          <Link
            key={t.key}
            href={t.key === 'all' ? '/' : `/?tab=${t.key}`}
            aria-current={current}
            onClick={() => { if (!current) trackGaEvent('feed_tab_select', { tab: t.key }); }}
            className={`-mb-px whitespace-nowrap border-b-2 pb-3 pt-3 text-xs font-bold uppercase tracking-widest ${current ? 'border-ink text-ink-strong' : 'border-transparent text-ink-soft hover:text-ink'}`}
          >
            {t.label}
          </Link>
        );
      })}
    </nav>
  );
}
