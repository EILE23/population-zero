'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { Avatar } from '@/components/ui';
import { timeAgo } from '@/lib/content';
import type { ThreadSummary } from '../queries';

export function ThreadList({ threads, selected }: { threads: ThreadSummary[]; selected?: string }) {
  const [search, setSearch] = useState('');
  const [items, setItems] = useState(threads);
  useEffect(() => { setItems(threads); }, [threads]);
  useEffect(() => {
    let alive = true;
    const timer = setInterval(async () => {
      if (document.hidden) return;
      try {
        const res = await fetch('/api/dm', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json() as { threads: ThreadSummary[] };
        if (alive) setItems(data.threads);
      } catch { /* Keep the last successful inbox during a connection failure. */ }
    }, 10000);
    return () => { alive = false; clearInterval(timer); };
  }, []);
  const visible = items.filter(t => t.other.handle.toLowerCase().includes(search.toLowerCase()));
  return <>
    <div className="border-b border-hairline p-4">
      <label htmlFor="conversation-search" className="sr-only">Search conversations</label>
      <input id="conversation-search" type="search" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search conversations" className="w-full rounded-lg border border-hairline bg-surface px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-accent" />
    </div>
    <ul className="min-h-0 flex-1 overflow-y-auto p-2">
      {visible.map(t => <li key={t.thread}>
        <Link href={`/messages/${encodeURIComponent(t.thread)}`} aria-current={selected === t.thread ? 'page' : undefined} className={`mb-1 flex items-center gap-3 rounded-xl p-3 focus-visible:outline-accent ${selected === t.thread ? 'bg-surface-deep' : 'hover:bg-surface'}`}>
          <Avatar handle={t.other.handle} size={36} isHuman={t.other.kind === 'user'} src={t.other.avatar} />
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2"><span className="truncate text-sm font-semibold">{t.other.handle}</span>{t.other.kind === 'resident' && <span className="text-[10px] text-ink-soft">AI</span>}</div>
            <p className={`truncate text-xs ${t.unread ? 'font-semibold text-ink' : 'text-ink-soft'}`}>{t.preview || 'Photo'}</p>
            <span className="text-[10px] text-ink-soft">{timeAgo(t.created_at)}</span>
          </div>
          {t.unread > 0 && <span aria-label={`${t.unread} unread`} className="rounded-full bg-accent px-2 py-0.5 text-xs text-paper">{t.unread > 99 ? '99+' : t.unread}</span>}
        </Link>
      </li>)}
      {!visible.length && <li className="px-4 py-8 text-center text-sm text-ink-soft">{items.length ? 'No matching conversations.' : 'No conversations yet. Open a profile and select Message to start.'}</li>}
    </ul>
    <p className="border-t border-hairline px-4 py-3 text-xs text-ink-soft">Start a conversation from someone’s profile.</p>
  </>;
}
