import Link from 'next/link';
import { MessageCircle } from 'lucide-react';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { NotificationsBell } from '@/features/notifications/NotificationsBell';
import { UserMenu } from './UserMenu';
import { MessagesBadge } from '@/features/messages/components/MessagesBadge';

/** 헤더 우측 네비 — 사이트 마스트헤드와 블로그 크롬이 공유한다. 알림 개수는 클라이언트가 나중에 가져온다 */
export async function NavActions() {
  let user = null;
  let unread = 0;
  try {
    user = await getSessionUser();
    // 쪽지함 바로가기의 안 읽은 메시지 배지.
    if (user) {
      const db = await getDb();
      const row = await db.prepare(`SELECT COUNT(*) AS n FROM dms WHERE to_user_id = ? AND read_at IS NULL`)
        .bind(user.id).first<{ n: number }>();
      unread = row?.n ?? 0;
    }
  } catch { /* DB 미초기화 시에도 셸은 렌더 */ }

  return (
    <nav className="flex w-full items-center gap-4 text-sm font-semibold text-ink-mid sm:w-auto sm:gap-6 lg:gap-7">
      <form action="/" className="min-w-0 flex-1 sm:flex-none">
        <input
          name="q"
          placeholder="Search"
          aria-label="Search"
          className="w-full border-0 border-b border-hairline bg-transparent px-1 py-1.5 text-sm font-normal outline-none transition-all placeholder:text-ink-soft focus:border-b-2 focus:border-accent sm:w-40 sm:focus:w-52"
        />
      </form>
      {/* 모바일에선 검색·핵심 액션에 폭을 양보 — About/Contact 는 푸터에서 항상 접근 가능 */}
      <Link className="hidden whitespace-nowrap hover:text-ink-strong sm:inline" href="/about">About</Link>
      <Link className="hidden whitespace-nowrap hover:text-ink-strong sm:inline" href="/contact">Contact</Link>
      {user
        ? (
          <>
            {/* 좁은 화면에선 아이콘 둘을 접는다 — 검색·Write·계정 메뉴만 남고, 알림·쪽지는 계정 메뉴 안에서 간다 */}
            <span className="hidden sm:inline-flex"><NotificationsBell /></span>
            <Link href="/messages" title="Messages" aria-label={unread > 0 ? `Messages, ${unread} unread` : 'Messages'} className="relative hidden shrink-0 items-center rounded-md p-1 text-ink sm:inline-flex hover:text-ink-strong focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-accent">
              <MessageCircle size={20} strokeWidth={2.2} aria-hidden />
              <MessagesBadge initial={unread} />
            </Link>
            <Link className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/write">Write</Link>
            <UserMenu handle={user.handle} avatarUrl={user.avatar_url} unread={unread} />
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
