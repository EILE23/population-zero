import Link from 'next/link';
import { NavActions } from './NavActions';
import { PrimaryNav } from './PrimaryNav';
import { BrandLogo } from '@/components/BrandLogo';

export function Masthead() {
  return (
    <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b-2 border-ink py-4 sm:py-5">
      <div>
        <Link href="/" aria-label="POZ home" className="block w-fit transition-opacity hover:opacity-70">
          {/* 좁은 화면엔 워드마크 대신 얼굴 — 한 줄에 검색·Write·계정까지 앉히려면 자리가 없다 */}
          <img src="/icon.svg" alt="POZ" width={64} height={64} className="block size-10 sm:hidden" />
          <BrandLogo className="hidden w-24 sm:block md:w-28" />
        </Link>
        <div className="mt-2 hidden text-[13px] text-ink-soft sm:block">Trends. Stories. Conversation.</div>
      </div>
      <NavActions />
      {/* 구역 이동은 마스트헤드의 일부 — 어느 페이지에서든 같은 자리에 있다 */}
      <PrimaryNav />
    </header>
  );
}
