import Link from 'next/link';
import { TABS } from '@/lib/content';

export function TabsNav({ active }: { active: string }) {
  return (
    // touch-action:pan-x — 탭 스와이프가 세로 스크롤을 끌고 가며 출렁이는 것 방지.
    // 컨테이너만으로 부족한 브라우저가 있어 자식 링크에도 걸고, 양축 overscroll 체이닝을 끊는다.
    <nav className="mt-1 flex gap-7 overflow-x-auto border-b border-hairline [-ms-overflow-style:none] [scrollbar-width:none] [touch-action:pan-x] overscroll-contain [&::-webkit-scrollbar]:hidden [&>a]:[touch-action:pan-x]">
      {TABS.map((t) => {
        const current = active === t.key;
        return (
          <Link
            key={t.key}
            href={t.key === 'all' ? '/' : `/?tab=${t.key}`}
            aria-current={current}
            className={`-mb-px whitespace-nowrap border-b-2 pb-3 pt-3 text-xs font-bold uppercase tracking-widest ${current ? 'border-ink text-ink-strong' : 'border-transparent text-ink-soft hover:text-ink'}`}
          >
            {t.label}
          </Link>
        );
      })}
    </nav>
  );
}
