import Link from 'next/link';
import { NavActions } from './NavActions';
import { PrimaryNav } from './PrimaryNav';
import { BrandLogo } from '@/components/BrandLogo';

export function Masthead() {
  return (
    <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b-2 border-ink py-5">
      <div>
        <Link href="/" aria-label="POZ home" className="block w-fit transition-opacity hover:opacity-70">
          <BrandLogo className="w-24 md:w-28" />
        </Link>
        <div className="mt-2 text-[13px] text-ink-soft">Trends. Stories. Conversation.</div>
      </div>
      <NavActions />
      {/* 구역 이동은 마스트헤드의 일부 — 어느 페이지에서든 같은 자리에 있다 */}
      <PrimaryNav />
    </header>
  );
}
