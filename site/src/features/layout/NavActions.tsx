import Link from 'next/link';
import { MessageCircle } from 'lucide-react';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { NotificationsBell } from '@/features/notifications/NotificationsBell';
import { UserMenu } from './UserMenu';
import { MessagesBadge } from '@/features/messages/components/MessagesBadge';

/**
 * 헤더 우측 네비 — 사이트 마스트헤드와 블로그 크롬이 공유한다. 알림 개수는 클라이언트가 나중에 가져온다.
 *
 * `items` 를 주면 그 항목만, 그 순서로 그린다(블로그 주인이 자기 블로그에서 정한 순서).
 * 안 주면 사이트 기본 순서 그대로 — 블로그 밖에서는 아무것도 달라지지 않는다.
 * 계정 메뉴는 목록에서 빠져도 그린다: 로그아웃과 내 자리로 가는 유일한 문이다(cleanLayout 도 같은 보장을 한다).
 */
export async function NavActions({ items }: { items?: readonly string[] } = {}) {
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

  const show = (k: string) => !items || items.includes(k);
  const order = items ? [...items] : null;

  const pieces: Record<string, React.ReactNode> = {
    search: (
      <form key="search" action="/" className="min-w-0 flex-1 sm:flex-none">
        <input
          name="q"
          placeholder="Search"
          aria-label="Search"
          className="w-full border-0 border-b border-hairline bg-transparent px-1 py-1.5 text-sm font-normal outline-none transition-all placeholder:text-ink-soft focus:border-b-2 focus:border-accent sm:w-40 sm:focus:w-52"
        />
      </form>
    ),
    // 모바일에선 검색·핵심 액션에 폭을 양보 — About/Contact 는 푸터에서 항상 접근 가능
    blogs: <Link key="blogs" className="hidden whitespace-nowrap hover:text-ink-strong sm:inline" href="/blogs">Blogs</Link>,
    about: <Link key="about" className="hidden whitespace-nowrap hover:text-ink-strong sm:inline" href="/about">About</Link>,
    contact: <Link key="contact" className="hidden whitespace-nowrap hover:text-ink-strong sm:inline" href="/contact">Contact</Link>,
    bell: user ? <span key="bell" className="hidden sm:inline-flex"><NotificationsBell /></span> : null,
    messages: user ? (
      <Link key="messages" href="/messages" title="Messages" aria-label={unread > 0 ? `Messages, ${unread} unread` : 'Messages'} className="relative hidden shrink-0 items-center rounded-md p-1 text-ink sm:inline-flex hover:text-ink-strong focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-accent">
        <MessageCircle size={20} strokeWidth={2.2} aria-hidden />
        <MessagesBadge initial={unread} />
      </Link>
    ) : null,
    write: user ? <Link key="write" className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/write">Write</Link> : null,
    account: user
      ? <UserMenu key="account" handle={user.handle} avatarUrl={user.avatar_url} unread={unread} />
      : (
        <span key="account" className="flex items-center gap-4 sm:gap-6">
          <Link className="whitespace-nowrap hover:text-ink-strong" href="/login">Log in</Link>
          <Link className="whitespace-nowrap rounded-full bg-ink px-4 py-1.5 text-paper hover:opacity-85" href="/login?mode=signup">Sign up</Link>
        </span>
      ),
  };

  const keys = order ?? ['search', 'blogs', 'about', 'contact', 'bell', 'messages', 'write', 'account'];
  return (
    <nav className="flex w-full items-center gap-4 text-sm font-semibold text-ink-mid sm:w-auto sm:gap-6 lg:gap-7">
      {keys.filter(show).map((k) => pieces[k] ?? null)}
    </nav>
  );
}
