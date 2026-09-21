'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

/**
 * 마스트헤드 아래 한 줄 — 사이트의 두 구역.
 * Community 는 글을 읽는 곳, News 는 남의 기사를 고르는 곳. 앨범(릴스)은 앱에만 있다.
 * 주제 탭(Ask·Tech…)은 Community 안의 분류라 여기 섞지 않는다.
 */
// 알림(/alerts)은 여기 없다 — 주 기능이 아니라 계정에 딸린 도구라 푸터와 계정 메뉴에만 둔다.
// Memes 가 첫 자리 — 이 사이트에서 사람이 '만드는' 곳이라서. Ask 는 뺐다(2026-09-21).
const SECTIONS = [
  { href: '/memes', label: 'Memes', match: (p: string) => p.startsWith('/memes') || p.startsWith('/m/') },
  { href: '/', label: 'Community', match: (p: string) => !p.startsWith('/news') && !p.startsWith('/memes') && !p.startsWith('/m/') && !p.startsWith('/blogs') },
  { href: '/blogs', label: 'Blogs', match: (p: string) => p.startsWith('/blogs') },
  { href: '/news', label: 'News', match: (p: string) => p.startsWith('/news') },
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
