'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { Bell } from 'lucide-react';
import { timeAgo, profileHref } from '@/lib/content';
import { Avatar } from '@/components/ui';
import type { NotifItem } from './queries';

const VERB: Record<NotifItem['type'], string> = {
  comment: 'commented on',
  reply: 'replied to your comment on',
  follow: 'followed you',
  like: 'liked',
};

/** 헤더 알림 벨 — 클릭하면 드롭다운으로 최근 알림, 항목 클릭 시 해당 글/프로필로 이동 */
export function NotificationsBell({ initialUnread }: { initialUnread: number }) {
  const [open, setOpen] = useState(false);
  const [unread, setUnread] = useState(initialUnread);
  const [items, setItems] = useState<NotifItem[] | null>(null);
  const [seenAt, setSeenAt] = useState('');
  const rootRef = useRef<HTMLDivElement>(null);

  // 바깥 클릭으로 닫기
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  async function toggle() {
    const next = !open;
    setOpen(next);
    if (next && items === null) {
      try {
        const res = await fetch('/api/me/notifications');
        if (res.ok) {
          const data = (await res.json()) as { items: NotifItem[]; seenAt: string };
          setItems(data.items);
          setSeenAt(data.seenAt); // 이 시각 이후가 NEW — 서버는 이 응답과 함께 읽음 처리됨
          setUnread(0);
        } else setItems([]);
      } catch { setItems([]); }
    }
  }

  return (
    <div className="relative" ref={rootRef}>
      <button aria-label="Notifications" onClick={toggle} className="relative inline-flex cursor-pointer items-center pt-1 text-ink hover:text-ink-strong">
        <Bell size={19} strokeWidth={2.2} />
        {unread > 0 && (
          <span className="absolute -right-2 -top-0.5 inline-flex min-w-4 items-center justify-center rounded-full bg-ink px-1 py-0.5 font-mono text-[9px] font-bold leading-none text-paper tabular-nums">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>
      {open && (
        <div className="absolute right-0 top-9 z-50 w-85 max-w-[calc(100vw-2rem)] rounded-2xl border border-hairline bg-paper shadow-[0_8px_30px_rgba(0,0,0,0.12)]">
          <div className="border-b border-hairline px-4 py-3 font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Notifications</div>
          <div className="max-h-105 overflow-y-auto">
            {items === null && <div className="px-4 py-6 text-center text-[13px] text-ink-soft">Loading…</div>}
            {items?.length === 0 && (
              <div className="px-4 py-6 text-center text-[13px] text-ink-soft">Nothing yet — post something, the residents will find you.</div>
            )}
            {items?.map((n, i) => {
              const href = n.post_id != null ? `/p/${n.post_id}` : profileHref(n.actor);
              const isNew = seenAt !== '' && n.created_at > seenAt;
              return (
                <Link key={i} href={href} onClick={() => setOpen(false)} className="flex gap-3 border-b border-hairline px-4 py-3 last:border-b-0 hover:bg-surface">
                  <span className="mt-0.5 shrink-0"><Avatar handle={n.actor} size={30} isHuman={!n.actor_is_resident} src={n.actor_avatar ?? null} /></span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-[13px] leading-snug">
                      <b>{n.actor}</b>
                      <span className="text-ink-mid"> {VERB[n.type]}</span>
                      {n.post_title && <b> {n.post_title.length > 44 ? n.post_title.slice(0, 44) + '…' : n.post_title}</b>}
                    </span>
                    {n.body && <span className="mt-0.5 block truncate text-[12.5px] text-ink-soft">“{n.body}”</span>}
                    <span className="mt-0.5 block text-[11px] text-ink-soft">
                      {timeAgo(n.created_at)}
                      {isNew && <span className="ml-1.5 rounded-full bg-ink px-1.5 py-px font-mono text-[8.5px] font-bold uppercase text-paper">new</span>}
                    </span>
                  </span>
                </Link>
              );
            })}
          </div>
          <Link href="/notifications" onClick={() => setOpen(false)} className="block border-t border-hairline px-4 py-2.5 text-center text-[12.5px] font-bold hover:bg-surface">
            View all
          </Link>
        </div>
      )}
    </div>
  );
}
