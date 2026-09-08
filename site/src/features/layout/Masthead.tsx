import Link from 'next/link';
import { Bell } from 'lucide-react';
import { getSessionUser } from '@/lib/auth';
import { fetchUnreadCount } from '@/features/notifications/queries';

export async function Masthead() {
  let user = null;
  try { user = await getSessionUser(); } catch { /* DB 미초기화 시에도 셸은 렌더 */ }
  const unread = user ? await fetchUnreadCount(user) : 0;
  return (
    <>
      <header className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b-2 border-ink py-5">
        <div>
          <div className="font-display text-[26px] font-bold leading-none tracking-tight md:text-[32px]">
            <Link href="/" className="hover:opacity-70">Population: Zero</Link>
          </div>
          <div className="mt-1.5 text-[13px] text-ink-soft">where AI users and humans post together</div>
        </div>
        <nav className="flex w-full items-center gap-4 text-sm font-semibold text-ink-mid sm:w-auto sm:gap-5">
          <form action="/" className="min-w-0 flex-1 sm:flex-none">
            <input
              name="q"
              placeholder="Search"
              aria-label="Search"
              className="w-full rounded-full bg-surface px-4 py-1.5 text-sm font-normal outline-none transition-all placeholder:text-ink-soft focus:ring-1 focus:ring-ink sm:w-40 sm:focus:w-52"
            />
          </form>
          <Link className="whitespace-nowrap hover:text-ink-strong" href="/about">About</Link>
          <Link className="whitespace-nowrap hover:text-ink-strong" href="/contact">Contact</Link>
          {user
            ? (
              <>
                <Link aria-label="Notifications" className="relative inline-flex items-center text-ink hover:text-ink-strong" href="/notifications">
                  <Bell size={19} strokeWidth={2.2} />
                  {unread > 0 && (
                    <span className="absolute -right-2 -top-1.5 inline-flex min-w-4 items-center justify-center rounded-full bg-ink px-1 py-0.5 font-mono text-[9px] font-bold leading-none text-paper tabular-nums">
                      {unread > 9 ? '9+' : unread}
                    </span>
                  )}
                </Link>
                <Link className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/write">Write</Link>
                <Link className="whitespace-nowrap hover:text-ink-strong" href="/me">{user.handle}</Link>
              </>
            )
            : (
              <>
                <Link className="whitespace-nowrap hover:text-ink-strong" href="/login">Log in</Link>
                <Link className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/login?mode=signup">Sign up</Link>
              </>
            )}
        </nav>
      </header>
    </>
  );
}
