'use client';
import { useEffect, useRef, useState } from 'react';
import { PostCard, AdCard } from '@/components/ui';
import type { FeedPost } from '../types';

const PAGE = 8;      // 스크롤당 2줄(4열 기준)
const AD_EVERY = 9;  // 인피드 광고 간격 (첫 광고는 7번째 자리)

function SkeletonCard() {
  return (
    <div className="animate-pulse overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)]" aria-hidden>
      <div className="aspect-video bg-surface-deep/60" />
      <div className="flex flex-col gap-2.5 p-4">
        <div className="h-4 w-4/5 rounded bg-surface-deep/60" />
        <div className="h-3 w-full rounded bg-surface-deep/40" />
        <div className="h-3 w-2/3 rounded bg-surface-deep/40" />
        <div className="mt-3 flex items-center gap-2">
          <div className="h-5 w-5 rounded-full bg-surface-deep/60" />
          <div className="h-3 w-24 rounded bg-surface-deep/40" />
        </div>
      </div>
    </div>
  );
}

export function FeedGrid({ initial, tab, q, sort }: { initial: FeedPost[]; tab: string; q: string; sort: string }) {
  const [posts, setPosts] = useState(initial);
  const [done, setDone] = useState(initial.length < 32);
  const [loading, setLoading] = useState(false);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const stateRef = useRef({ offset: initial.length, loading: false, done: initial.length < 32 });

  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const io = new IntersectionObserver(async ([entry]) => {
      const s = stateRef.current;
      if (!entry.isIntersecting || s.loading || s.done) return;
      s.loading = true;
      setLoading(true);
      try {
        const qs = new URLSearchParams({ tab, q, sort, offset: String(s.offset) });
        const res = await fetch(`/api/feed?${qs}`);
        const more: FeedPost[] = res.ok ? await res.json() : [];
        s.offset += more.length;
        if (more.length < PAGE) { s.done = true; setDone(true); }
        if (more.length) setPosts((prev) => [...prev, ...more.filter((m) => !prev.some((p) => p.id === m.id))]);
      } catch { /* 다음 교차 때 재시도 */ }
      s.loading = false;
      setLoading(false);
    }, { rootMargin: '600px 0px' });
    io.observe(el);
    return () => io.disconnect();
  }, [tab, q, sort]);

  const cells: React.ReactNode[] = [];
  posts.forEach((p, i) => {
    cells.push(<PostCard key={p.id} post={p} />);
    if (i === 5 || (i > 5 && (i - 5) % AD_EVERY === 0)) cells.push(<AdCard key={`ad-${i}`} />);
  });

  return (
    <>
      <div className="mt-7 grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {cells}
        {loading && Array.from({ length: PAGE }, (_, i) => <SkeletonCard key={`sk-${i}`} />)}
      </div>
      {!done && <div ref={sentinelRef} className="h-px" aria-hidden />}
    </>
  );
}
