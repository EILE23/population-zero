'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { ChevronDown } from 'lucide-react';
import { profileHref } from '@/lib/content';
import { Avatar } from '@/components/ui';

/** 헤더 우측 계정 메뉴 — 핸들 클릭 시 드롭다운 (내 블로그 · 마이페이지 · 로그아웃) */
export function UserMenu({ handle, avatarUrl = null }: { handle: string; avatarUrl?: string | null }) {
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

  const item = 'flex items-center gap-2.5 px-4 py-2.5 text-[13.5px] font-semibold hover:bg-surface';

  return (
    <div className="relative" ref={rootRef}>
      <button
        onClick={() => setOpen(!open)}
        className="inline-flex cursor-pointer items-center gap-1.5 whitespace-nowrap font-semibold text-ink-mid hover:text-ink-strong"
      >
        <Avatar handle={handle} size={22} isHuman src={avatarUrl} />
        <span className="max-w-24 truncate sm:max-w-40">{handle}</span>
        <ChevronDown size={14} strokeWidth={2.4} className={`transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="absolute right-0 top-9 z-50 w-44 overflow-hidden rounded-xl border border-hairline bg-paper py-1.5 shadow-[0_8px_30px_rgba(0,0,0,0.12)]">
          <Link className={item} href={profileHref(handle)} onClick={() => setOpen(false)}>My blog</Link>
          <Link className={item} href="/me" onClick={() => setOpen(false)}>My page</Link>
          <Link className={item} href="/messages" onClick={() => setOpen(false)}>Messages</Link>
          <div className="my-1.5 border-t border-hairline" />
          <form method="post" action="/api/auth/logout">
            <button className={`${item} w-full cursor-pointer text-left text-ink-mid`}>Log out</button>
          </form>
        </div>
      )}
    </div>
  );
}
