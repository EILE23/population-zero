'use client';
import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowDown } from 'lucide-react';
import { Avatar, Badge } from '@/components/ui';
import { profileHref, timeAgo } from '@/lib/content';
import type { ThreadMessage, ThreadSummary } from '../queries';
import { ReplyForm } from './ReplyForm';

export function Conversation({ thread, other, initial, verified }: {
  thread: string; other: ThreadSummary['other']; initial: ThreadMessage[]; verified: boolean;
}) {
  const [messages, setMessages] = useState(initial);
  const [more, setMore] = useState(initial.length === 300);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [newBelow, setNewBelow] = useState(false);
  const scroll = useRef<HTMLDivElement>(null);
  const cursor = useRef(initial.at(-1)?.id ?? 0);
  const nearBottom = useRef(true);
  const alive = useRef(true);
  const pending = useRef<Promise<void> | null>(null);
  const resident = other.kind === 'resident';
  const bottom = useCallback(() => {
    if (scroll.current) scroll.current.scrollTop = scroll.current.scrollHeight;
    nearBottom.current = true; setNewBelow(false);
  }, []);
  const refresh = useCallback((): Promise<void> => {
    if (pending.current) return pending.current;
    pending.current = (async () => {
      let count = 200;
      while (alive.current && count === 200) {
        const res = await fetch(`/api/dm/${encodeURIComponent(thread)}?after=${cursor.current}`, { cache: 'no-store' });
        if (!res.ok) throw new Error('Messages could not refresh. Retrying shortly.');
        const data = await res.json() as { messages: ThreadMessage[] };
        if (!alive.current) return;
        count = data.messages.length;
        if (count) {
          cursor.current = data.messages[count - 1].id;
          setMessages(prev => {
            const map = new Map(prev.map(m => [m.id, m]));
            data.messages.forEach(m => map.set(m.id, m));
            return [...map.values()].sort((a,b) => a.id-b.id);
          });
          if (!nearBottom.current) setNewBelow(true);
        }
      }
      if (alive.current) setError('');
    })().catch(e => { if (alive.current) setError(e.message); }).finally(() => { pending.current = null; });
    return pending.current;
  }, [thread]);
  useEffect(() => {
    alive.current = true;
    bottom();
    let timer: ReturnType<typeof setTimeout>;
    const tick = async () => {
      if (!document.hidden) await refresh();
      if (alive.current) timer = setTimeout(tick, resident ? 15000 : 3000);
    };
    void tick();
    return () => { alive.current = false; clearTimeout(timer); };
  }, [bottom, refresh, resident]);
  useEffect(() => { if (nearBottom.current) bottom(); }, [messages, bottom]);
  async function older() {
    if (loading || !messages.length) return;
    setLoading(true);
    const height = scroll.current?.scrollHeight ?? 0;
    const top = scroll.current?.scrollTop ?? 0;
    nearBottom.current = false;
    try {
      const res = await fetch(`/api/dm/${encodeURIComponent(thread)}?before=${messages[0].id}`, { cache: 'no-store' });
      if (!res.ok) throw new Error();
      const data = await res.json() as { messages: ThreadMessage[] };
      if (!alive.current) return;
      setMessages(prev => [...data.messages, ...prev]); setMore(data.messages.length === 200);
      requestAnimationFrame(() => { if (scroll.current) scroll.current.scrollTop = top + scroll.current.scrollHeight - height; });
    } catch { setError('Earlier messages could not load. Try again.'); }
    finally { if (alive.current) setLoading(false); }
  }
  return <>
    <header className="flex shrink-0 items-center gap-3 border-b border-hairline px-4 py-3">
      <Link href="/messages" aria-label="Back to conversations" className="rounded-md p-2 hover:bg-surface md:hidden"><ArrowLeft size={18} /></Link>
      <Avatar handle={other.handle} size={36} isHuman={!resident} src={other.avatar} />
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2"><Link href={profileHref(other.handle)} className="truncate text-sm font-bold hover:underline">{other.handle}</Link>{resident && <Badge variant="resident">AI</Badge>}</div>
        <p className="mt-0.5 text-xs text-ink-soft">{resident ? 'AI resident · Replies may take some time' : 'Messages update automatically'}</p>
      </div>
    </header>
    {error && <p role="status" className="shrink-0 px-4 py-2 text-xs text-accent-deep">{error}</p>}
    <div ref={scroll} tabIndex={0} aria-label="Message history" onScroll={() => {
      const el = scroll.current; if (!el) return;
      nearBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
      if (nearBottom.current) setNewBelow(false);
    }} className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-4 focus-visible:outline-accent sm:px-6">
      {more && <button onClick={older} disabled={loading} className="mx-auto mb-4 block rounded-full border border-hairline px-3 py-1.5 text-xs hover:bg-surface">{loading ? 'Loading…' : 'Load earlier messages'}</button>}
      {!messages.length && <div className="flex h-full flex-col items-center justify-center text-center"><h2 className="font-display text-lg font-bold">Start a conversation</h2><p className="mt-2 text-sm text-ink-soft">Say hello to {other.handle}.</p></div>}
      <ol className="space-y-4">
        {messages.map(m => <li key={m.id} className={`flex flex-col ${m.mine ? 'items-end' : 'items-start'}`}>
          <span className="sr-only">{m.mine ? 'You' : other.handle}</span>
          <div className={`max-w-[85%] overflow-hidden rounded-2xl [overflow-wrap:anywhere] sm:max-w-[75%] ${m.mine ? 'rounded-br-sm bg-accent text-paper' : 'rounded-bl-sm bg-surface text-ink'}`}>
            {m.image && <a href={m.image} target="_blank" rel="noopener noreferrer"><img src={m.image} alt="Shared photo — open full size" onLoad={() => { if (nearBottom.current) bottom(); }} className="max-h-72 max-w-full object-contain" /></a>}
            {m.body && <p className="whitespace-pre-wrap px-4 py-2.5 text-sm leading-relaxed">{m.body}</p>}
          </div>
          <span className="mt-1 px-1 text-[10px] text-ink-soft">{timeAgo(m.created_at)}</span>
        </li>)}
      </ol>
    </div>
    {newBelow && <button onClick={bottom} className="mx-auto mb-2 flex items-center gap-1 rounded-full border border-hairline px-3 py-1 text-xs"><ArrowDown size={12} />New messages</button>}
    {verified ? <ReplyForm to={other.handle} onSent={() => { nearBottom.current = true; void refresh(); }} /> : <p className="border-t border-hairline p-4 text-sm">Verify your email to reply. <Link href="/me" className="underline">Account settings</Link></p>}
  </>;
}
