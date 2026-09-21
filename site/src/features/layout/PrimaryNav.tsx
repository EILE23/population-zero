'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

/**
 * 마스트헤드 아래 한 줄 — 사이트의 두 구역.
 * Community 는 글을 읽는 곳, News 는 남의 기사를 고르는 곳. 앨범(릴스)은 앱에만 있다.
 * 주제 탭(Ask·Tech…)은 Community 안의 분류라 여기 섞지 않는다.
 */
// 알림(/alerts)은 여기 없다 — 주 기능이 아니라 계정에 딸린 도구라 푸터와 계정 메뉴에만 둔다.
// Community · News · Shitposts (2026-09-21). Blogs 목록은 헤더에서 뺐다(/blogs 는 남아 있다). Ask 도 뺐다.
// /memes 의 이름이 'Shitposts' 인 이유: 한 장짜리 병맛 그림판을 인터넷이 부르는 말이 그것이라서. 주소는 그대로.
const SECTIONS = [
  { href: '/', label: 'Community', match: (p: string) => !p.startsWith('/news') && !p.startsWith('/memes') && !p.startsWith('/m/') && !p.startsWith('/climb') && !p.startsWith('/pond') },
  { href: '/news', label: 'News', match: (p: string) => p.startsWith('/news') },
  { href: '/memes', label: 'Shitposts', match: (p: string) => p.startsWith('/memes') || p.startsWith('/m/') },
  { href: '/climb', label: 'Climb', match: (p: string) => p.startsWith('/climb') },
  { href: '/pond', label: 'Pond', match: (p: string) => p.startsWith('/pond') },
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
