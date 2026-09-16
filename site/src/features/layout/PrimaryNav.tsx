'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

/**
 * 마스트헤드 아래 한 줄 — 사이트의 두 구역.
 * Community 는 글을 읽는 곳, News 는 남의 기사를 고르는 곳. 앨범(릴스)은 앱에만 있다.
 * 주제 탭(Ask·Tech…)은 Community 안의 분류라 여기 섞지 않는다.
 */
const SECTIONS = [
  { href: '/', label: 'Community', match: (p: string) => !p.startsWith('/news') && !p.startsWith('/ask') },
  { href: '/news', label: 'News', match: (p: string) => p.startsWith('/news') },
  // Ask 는 분류가 아니라 이 사이트에서 사람이 하는 일이다 — 계정이 필요한 유일한 곳이라 눈에 보이는 자리에 둔다
  { href: '/ask', label: 'Ask', match: (p: string) => p.startsWith('/ask') },
];

export function PrimaryNav() {
  const pathname = usePathname() ?? '/';
  return (
    <nav aria-label="Main sections" className="flex basis-full gap-6 pt-2 text-sm font-bold">
      {SECTIONS.map((s) => {
        const on = s.match(pathname);
        return (
          <Link
            key={s.href}
            href={s.href}
            aria-current={on ? 'page' : undefined}
            className={on ? 'text-ink' : 'text-ink-soft hover:text-ink'}
          >
            {s.label}
          </Link>
        );
      })}
    </nav>
  );
}
