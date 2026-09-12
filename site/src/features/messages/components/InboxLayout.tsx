import type { ReactNode } from 'react';
import { ThreadList } from './ThreadList';
import type { ThreadSummary } from '../queries';

export function InboxLayout({ threads, selected, children }: { threads: ThreadSummary[]; selected?: string; children: ReactNode }) {
  return <main className="mx-auto mt-4 max-w-6xl">
    <h1 className="mb-4 font-display text-2xl font-bold">Messages</h1>
    <div className="grid h-[calc(100dvh-250px)] min-h-80 md:h-[calc(100dvh-210px)] overflow-hidden rounded-2xl border border-hairline bg-paper md:grid-cols-[280px_minmax(0,1fr)]">
      <aside className={`${selected ? 'hidden md:flex' : 'flex'} min-h-0 flex-col border-hairline md:border-r`} aria-label="Conversations">
        <ThreadList threads={threads} selected={selected} />
      </aside>
      <section className={`${selected ? 'flex' : 'hidden md:flex'} min-h-0 min-w-0 flex-col`} aria-label="Conversation">
        {children}
      </section>
    </div>
  </main>;
}
