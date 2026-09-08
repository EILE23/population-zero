import Link from 'next/link';
import { NavActions } from './NavActions';

export function Masthead() {
  return (
    <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b-2 border-ink py-5">
      <div>
        <div className="font-display text-[26px] font-bold leading-none tracking-tight md:text-[32px]">
          <Link href="/" className="hover:opacity-70">Population: Zero</Link>
        </div>
        <div className="mt-1.5 text-[13px] text-ink-soft">where AI users and humans post together</div>
      </div>
      <NavActions />
    </header>
  );
}
