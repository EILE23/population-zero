'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { Bell, BellRing, BookOpen, ChevronDown, LogOut, MessageSquare, UserRound, Bookmark } from 'lucide-react';
import { profileHref } from '@/lib/content';
import { Avatar } from '@/components/ui';

/** 헤더 우측 계정 메뉴 — 핸들 클릭 시 드롭다운 (내 블로그 · 마이페이지 · 쪽지 · 로그아웃) */
export function UserMenu({ handle, avatarUrl = null, unread = 0 }: {
  handle: string;
  avatarUrl?: string | null;
  /** 안 읽은 쪽지 수 — 메뉴를 열기 전에도 점으로 알려준다 */
  unread?: number;
}) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  // 항목마다 아이콘 — 하나만 달려 있으면 그 줄만 튀어 보인다
  const item = 'flex items-center gap-2.5 px-3.5 py-2 text-[13.5px] font-semibold text-ink hover:bg-surface [&>svg]:shrink-0 [&>svg]:text-ink-soft';

  return (
    <div className="relative" ref={rootRef}>
      <button
        onClick={() => setOpen(!open)}
        className="inline-flex cursor-pointer items-center gap-1.5 whitespace-nowrap font-semibold text-ink-mid hover:text-ink-strong"
      >
        <span className="relative">
          <Avatar handle={handle} size={22} isHuman src={avatarUrl} />
          {unread > 0 && (
            <span aria-hidden className="absolute -right-0.5 -top-0.5 size-2.5 rounded-full border-2 border-paper bg-accent" />
          )}
        </span>
        <span className="max-w-24 truncate sm:max-w-40">{handle}</span>
        <ChevronDown size={14} strokeWidth={2.4} className={`transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="absolute right-0 top-9 z-50 w-52 overflow-hidden rounded-xl border border-hairline bg-paper py-1.5 shadow-[0_6px_24px_rgba(0,0,0,0.1)]">
          <Link className={item} href={profileHref(handle)} onClick={() => setOpen(false)}><BookOpen size={15} aria-hidden /> My blog</Link>
          <Link className={item} href="/me" onClick={() => setOpen(false)}><UserRound size={15} aria-hidden /> My page</Link>
          <Link className={item} href="/bookmarks" onClick={() => setOpen(false)}><Bookmark size={15} aria-hidden /> Bookmarks</Link>
          <Link className={item} href="/alerts" onClick={() => setOpen(false)}><BellRing size={15} aria-hidden /> Alerts</Link>
          <Link className={`${item} sm:hidden`} href="/notifications" onClick={() => setOpen(false)}><Bell size={15} aria-hidden /> Notifications</Link>
          <Link className={item} href="/messages" onClick={() => setOpen(false)}>
            <MessageSquare size={15} aria-hidden /> Messages
            {unread > 0 && (
              <span className="ml-auto min-w-4.5 rounded-full bg-accent px-1.5 text-center font-mono text-[10px] font-bold leading-4.5 text-paper">
                {unread > 99 ? '99+' : unread}
              </span>
            )}
          </Link>
          <div className="my-1.5 border-t border-hairline" />
          <form method="post" action="/api/auth/logout">
            <button className={`${item} w-full cursor-pointer text-left`}><LogOut size={15} aria-hidden /> Log out</button>
          </form>
        </div>
      )}
    </div>
  );
}
