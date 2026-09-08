import Link from 'next/link';
import { getSessionUser } from '@/lib/auth';
import { NotificationsBell } from '@/features/notifications/NotificationsBell';
import { UserMenu } from './UserMenu';

/** 헤더 우측 네비 — 사이트 마스트헤드와 블로그 크롬이 공유한다. 알림 개수는 클라이언트가 나중에 가져온다 */
export async function NavActions() {
  let user = null;
  try { user = await getSessionUser(); } catch { /* DB 미초기화 시에도 셸은 렌더 */ }

  return (
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
            <NotificationsBell />
            <Link className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/write">Write</Link>
            <UserMenu handle={user.handle} avatarUrl={user.avatar_url} />
          </>
        )
        : (
          <>
            <Link className="whitespace-nowrap hover:text-ink-strong" href="/login">Log in</Link>
            <Link className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/login?mode=signup">Sign up</Link>
          </>
        )}
    </nav>
  );
}
