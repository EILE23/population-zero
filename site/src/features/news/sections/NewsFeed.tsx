'use client';

import { useEffect, useRef, useState } from 'react';
import { ArrowUpRight } from 'lucide-react';
import { AdSlot } from '@/components/ui';
import { timeAgo } from '@/lib/content';
import type { WireItem, WireKind, WirePage } from '../types';

const PAGE = 18;
const AD_EVERY = 9;

const REGION_NAME: Record<string, string> = {
  US: 'the US', GB: 'the UK', KR: 'Korea', JP: 'Japan', IN: 'India', BR: 'Brazil',
  DE: 'Germany', FR: 'France', MX: 'Mexico', AU: 'Australia', ID: 'Indonesia', NG: 'Nigeria',
};

/** 출처 · 시간 — 모든 카드가 같은 자리에 같은 순서로 */
function Byline({ item }: { item: WireItem }) {
  return (
    <div className="flex min-w-0 items-baseline gap-2 font-mono text-[10.5px] uppercase tracking-widest text-ink-soft">
      <span className="truncate font-bold text-ink-mid">{item.source ?? 'Source'}</span>
      <span className="shrink-0">· {timeAgo(item.collected_at)}</span>
    </div>
  );
}

/** 카드 전체가 링크 — 기사는 여기서 읽는 게 아니라 원문에서 읽는다 */
function Card({ item, lead }: { item: WireItem; lead?: boolean }) {
  const href = item.url && /^https?:\/\//.test(item.url) ? item.url : null;
  const Tag = href ? 'a' : 'div';
  const linkProps = href ? { href, target: '_blank', rel: 'noopener noreferrer' } : {};

  if (lead) {
    return (
      <Tag
        {...linkProps}
        className="group col-span-full grid gap-5 rounded-2xl bg-paper p-5 shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-shadow hover:shadow-[0_4px_16px_rgba(0,0,0,0.1)] md:grid-cols-[1.25fr_1fr] md:p-6"
      >
        {item.image && (
          <div className="aspect-[16/10] overflow-hidden rounded-xl bg-surface-deep">
            <img src={item.image} alt="" loading="eager" className="size-full object-cover transition-transform duration-500 group-hover:scale-[1.02]" />
          </div>
        )}
        <div className="flex min-w-0 flex-col justify-center">
          <Byline item={item} />
          <h2 className="mt-3 font-display text-[26px] font-bold leading-[1.15] tracking-tight [text-wrap:balance] md:text-[30px]">
            {item.title}
          </h2>
          {item.summary && <p className="mt-3 line-clamp-4 text-[14.5px] leading-relaxed text-ink-mid">{item.summary}</p>}
          {href && (
            <span className="mt-4 inline-flex items-center gap-1 text-[12.5px] font-bold text-ink group-hover:underline">
              Read at {item.source ?? 'the source'} <ArrowUpRight size={14} />
            </span>
          )}
        </div>
      </Tag>
    );
  }

  return (
    <Tag
      {...linkProps}
      className="group flex flex-col overflow-hidden rounded-2xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-shadow hover:shadow-[0_4px_16px_rgba(0,0,0,0.1)]"
    >
      {item.image && (
        <div className="aspect-[16/9] overflow-hidden bg-surface-deep">
          <img src={item.image} alt="" loading="lazy" className="size-full object-cover transition-transform duration-500 group-hover:scale-[1.03]" />
        </div>
      )}
      <div className="flex flex-1 flex-col p-4">
        <Byline item={item} />
        <h2 className="mt-2 line-clamp-3 font-display text-[17px] font-bold leading-snug">{item.title}</h2>
        {item.summary && <p className="mt-2 line-clamp-2 text-[13px] leading-relaxed text-ink-mid">{item.summary}</p>}
        {href && (
          <span className="mt-auto inline-flex items-center gap-1 pt-3 text-[11.5px] font-bold text-ink-soft group-hover:text-ink">
            Open <ArrowUpRight size={12} />
          </span>
        )}
      </div>
    </Tag>
  );
}

/**
 * News — 이 사람의 나라에서 지금 읽히는 것들. 앱의 Wire 와 같은 API, 같은 순서.
 *
 * 우리가 쓴 글이 아니라 남의 기사다. 그래서 본문을 옮겨 오지 않고(미리보기 + 출처 + 원문 링크),
 * 카드마다 어느 매체인지 먼저 보인다. 검색어 목록(keyword)은 제목뿐이라 카드가 되지 않으므로 빼 둔다.
 */
export function NewsFeed({ initialKind = 'news' }: { initialKind?: WireKind }) {
  const [kind, setKind] = useState<WireKind>(initialKind);
  const [items, setItems] = useState<WireItem[]>([]);
  const [region, setRegion] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(true);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const sentinel = useRef<HTMLDivElement>(null);
  const busy = useRef(false);

  // 종류가 바뀌면 처음부터 — offset 은 지금 가진 개수로 계산한다 (별도 상태를 두면 둘이 어긋난다)
  useEffect(() => {
    let alive = true;
    busy.current = true;
    setLoading(true);
    setFailed(false);
    setItems([]);
    fetch(`/api/trends?kind=${kind}&limit=${PAGE}`)
      .then(async (r) => { if (!r.ok) throw new Error(String(r.status)); return (await r.json()) as WirePage; })
      .then((page) => {
        if (!alive) return;
        setItems(page.items);
        setRegion(page.covered ? page.region : null);
        setHasMore(page.hasMore);
      })
      .catch(() => { if (alive) setFailed(true); })
      .finally(() => { if (alive) { setLoading(false); busy.current = false; } });
    return () => { alive = false; };
  }, [kind, attempt]);

  // 끝에 닿으면 다음 장 — 버튼도 남겨 둔다 (스크롤 감지가 안 되는 환경이 있다)
  useEffect(() => {
    const el = sentinel.current;
    if (!el || !hasMore || loading) return;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) void loadMore();
    }, { rootMargin: '600px 0px' });
    io.observe(el);
    return () => io.disconnect();
    // items.length 가 바뀔 때마다 다시 붙인다 — 한 장 받은 뒤에도 끝에 닿아 있으면 곧장 다음 장
  }, [hasMore, loading, items.length]);

  async function loadMore() {
    if (busy.current || !hasMore) return;
    busy.current = true;
    try {
      const r = await fetch(`/api/trends?kind=${kind}&offset=${items.length}&limit=${PAGE}`);
      if (!r.ok) throw new Error(String(r.status));
      const page = (await r.json()) as WirePage;
      setItems((prev) => {
        const seen = new Set(prev.map((i) => i.id));
        return [...prev, ...page.items.filter((i) => !seen.has(i.id))];
      });
      setHasMore(page.hasMore);
    } catch {
      setHasMore(false);
    } finally {
      busy.current = false;
    }
  }

  const where = region ? REGION_NAME[region] ?? region : null;

  return (
    <main className="mt-8">
      <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-4">
        <div>
          <h1 className="font-display text-[32px] font-bold leading-tight tracking-tight">News</h1>
          <p className="mt-2 max-w-150 text-[13px] text-ink-soft">
            {where ? `What people in ${where} are reading right now.` : 'What people are reading right now.'}
            {' '}Previews only — every story opens at its source.
          </p>
        </div>
        {/* 종류는 칩 두 개면 된다 — 드롭다운은 고를 게 많을 때의 도구다 */}
        <div role="tablist" aria-label="Kind" className="flex gap-2">
          {(['news', 'video'] as const).map((k) => {
            const on = kind === k;
            return (
              <button
                key={k}
                role="tab"
                aria-selected={on}
                onClick={() => setKind(k)}
                className={`rounded-full px-3.5 py-1.5 text-[12.5px] font-bold transition-colors ${on ? 'bg-ink text-paper' : 'border border-hairline text-ink-mid hover:bg-surface'}`}
              >
                {k === 'news' ? 'Stories' : 'Videos'}
              </button>
            );
          })}
        </div>
      </div>

      {failed && (
        <div className="mt-10 rounded-xl border border-hairline bg-surface p-6 text-center text-[13.5px]">
          <p className="font-semibold">The wire is down for a moment.</p>
          <button onClick={() => setAttempt((n) => n + 1)} className="mt-3 rounded-full bg-ink px-4 py-1.5 text-[12.5px] font-bold text-paper">Try again</button>
        </div>
      )}

      {!failed && !loading && items.length === 0 && (
        <p className="py-14 text-[13px] text-ink-soft">Nothing collected yet. The patrol brings the next batch within a few hours.</p>
      )}

      <div className="mt-6 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {items.map((item, i) => (
          <div key={item.id} className={`contents`}>
            <Card item={item} lead={i === 0 && !!item.image} />
            {(i + 1) % AD_EVERY === 0 && <div className="col-span-full"><AdSlot note="Sponsored" /></div>}
          </div>
        ))}
        {loading && Array.from({ length: 6 }, (_, i) => (
          <div key={`s${i}`} className="h-56 animate-pulse rounded-2xl bg-surface-deep/60" />
        ))}
      </div>

      <div ref={sentinel} className="mt-8 flex justify-center">
        {!loading && hasMore && (
          <button onClick={() => void loadMore()} className="rounded-full border border-hairline px-5 py-2 text-[13px] font-bold text-ink-mid hover:bg-surface">
            More stories
          </button>
        )}
        {!loading && !hasMore && items.length > 0 && (
          <p className="font-mono text-[10.5px] uppercase tracking-widest text-ink-faint">You’re up to date</p>
        )}
      </div>
    </main>
  );
}
