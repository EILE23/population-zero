'use client';

import { useEffect, useRef, useState } from 'react';
import { ArrowUpRight } from 'lucide-react';
import { timeAgo } from '@/lib/content';
import type { WireItem, WireKind, WirePage } from '../types';

const PAGE = 18;

/**
 * 취향 기록 — 앱의 Wire 와 같은 신호(view·open)를 같은 API 로 보낸다.
 * 로그인 전에도 이어지도록 기기 식별자를 localStorage 에 둔다. 제목은 보내지 않는다(분류·매체·종류만).
 */
const ANON_KEY = 'poz_anon_id';
function anonId(): string {
  try {
    const stored = localStorage.getItem(ANON_KEY);
    if (stored) return stored;
    const made = `w${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`;
    localStorage.setItem(ANON_KEY, made);
    return made;
  } catch { return ''; }
}

type Signal = { trend_id: number; action: 'view' | 'open' };
const QUEUE_MAX = 200;
const queue: Signal[] = [];
const seen = new Set<string>();
let flushTimer: ReturnType<typeof setTimeout> | null = null;
let sending = false;
let failures = 0;

/**
 * 큐는 서버가 받았다고 답한 뒤에만 비운다. 예전엔 보내기 전에 잘라내서 실패하면 그대로 사라졌다.
 * 실패하면 남겨 두고 조금 뒤(백오프) 다시 보낸다. 서버가 같은 항목·같은 행동을 6시간 안에 한 번만 남기므로
 * 재전송이 중복으로 쌓이지 않는다. 분류·매체는 보내지 않는다 — 서버가 trend_id 로 직접 읽는다.
 */
function flush(beacon = false) {
  if (flushTimer) { clearTimeout(flushTimer); flushTimer = null; }
  if (!queue.length || sending) return;
  const batch = queue.slice(0, 60);
  const body = JSON.stringify({ anon: anonId(), events: batch });
  const ack = () => { queue.splice(0, batch.length); failures = 0; };
  // 페이지를 떠나는 순간엔 fetch 가 잘리므로 beacon 으로 — 브라우저가 받아 주면(true) 전달을 맡긴 것이다
  if (beacon && navigator.sendBeacon) {
    if (navigator.sendBeacon('/api/trends/event', new Blob([body], { type: 'application/json' }))) { ack(); return; }
    // 거절(false)이면 아래 keepalive fetch 로 떨어진다
  }
  sending = true;
  fetch('/api/trends/event', { method: 'POST', headers: { 'content-type': 'application/json' }, body, keepalive: true })
    .then((r) => { if (r.ok) ack(); else throw new Error(String(r.status)); })
    .catch(() => {
      failures = Math.min(failures + 1, 6);
      if (!flushTimer) flushTimer = setTimeout(() => flush(), 2000 * 2 ** failures); // 4s → 8s → … 최대 ~2분
    })
    .finally(() => { sending = false; });
}

function record(item: WireItem, action: 'view' | 'open') {
  const key = `${action}:${item.id}`;
  if (seen.has(key)) return;
  seen.add(key);
  if (queue.length >= QUEUE_MAX) queue.shift(); // 오래 못 보낸 것부터 버린다 — 큐가 끝없이 자라지 않게
  queue.push({ trend_id: item.id, action });
  // 누른 건 바로, 스친 건 모아서
  if (action === 'open') flush();
  else if (!flushTimer) flushTimer = setTimeout(() => flush(), 4000);
}

/** 출처 · 시간 — 모든 카드가 같은 자리에 같은 순서로 */
function Byline({ item }: { item: WireItem }) {
  return (
    <div className="flex min-w-0 items-baseline gap-2 font-mono text-[10.5px] uppercase tracking-widest text-ink-soft">
      <span className="truncate font-bold text-ink-mid">{item.source ?? 'Source'}</span>
      <span className="shrink-0">· {timeAgo(item.collected_at)}</span>
    </div>
  );
}

/**
 * 칸의 모양 — 기본은 고른 3열, 리듬만 조금 준다.
 *  row  : 6칸 전부, 사진 왼쪽·제목 오른쪽 — 맨 위 한 장
 *  tile : 2칸(3열), 사진 위·제목 아래
 *  wide : 3칸(2열), 같은 구성에 사진만 넓게 — 여섯 장마다 한 쌍
 * 사진이 없는 항목은 어느 자리에 오든 글자 카드가 된다. 영상은 썸네일이 늘 있으니 첫 장만 크게, 나머지는 고르게.
 */
type Shape = 'wide' | 'tile' | 'row';
const STORY_CYCLE: Shape[] = ['tile', 'tile', 'tile', 'tile', 'tile', 'tile', 'wide', 'wide'];
function shapeFor(kind: WireKind, i: number): Shape {
  if (i === 0) return 'row';
  if (kind === 'video') return 'tile';
  return STORY_CYCLE[(i - 1) % STORY_CYCLE.length];
}
const SPAN: Record<Shape, string> = {
  wide: 'sm:col-span-1 lg:col-span-3',
  tile: 'sm:col-span-1 lg:col-span-2',
  row: 'sm:col-span-2 lg:col-span-6',
};

/** 카드 전체가 링크 — 기사는 여기서 읽는 게 아니라 원문에서 읽는다 */
function Card({ item, shape }: { item: WireItem; shape: Shape }) {
  const href = item.url && /^https?:\/\//.test(item.url) ? item.url : null;
  const Tag = href ? 'a' : 'div';
  const ref = useRef<HTMLElement>(null);
  const [broken, setBroken] = useState(false);
  const linkProps = href
    ? { href, target: '_blank', rel: 'noopener noreferrer', onClick: () => record(item, 'open') }
    : {};
  const image = broken ? null : item.image;

  // 화면에 절반 이상 들어와 있으면 '스쳤다' — 순위 신호 중 약한 쪽
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.intersectionRatio >= 0.5)) { record(item, 'view'); io.disconnect(); }
    }, { threshold: 0.5 });
    io.observe(el);
    return () => io.disconnect();
  }, [item]);

  const shell = `group overflow-hidden rounded-2xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-shadow hover:shadow-[0_4px_16px_rgba(0,0,0,0.1)] ${SPAN[shape]}`;
  // 매체가 링크 미리보기 이미지를 핫링크로 막는 경우가 있다 — referrer 를 보내지 않고, 깨지면 글자 카드로 내려간다
  const img = (cls: string, eager = false) => image && (
    <img src={image} alt="" loading={eager ? 'eager' : 'lazy'} referrerPolicy="no-referrer" onError={() => setBroken(true)}
      className={`${cls} object-cover transition-transform duration-500 group-hover:scale-[1.03]`} />
  );

  if (shape === 'row' && image) {
    return (
      <Tag ref={ref as never} {...linkProps} className={`${shell} grid gap-0 md:grid-cols-[1.2fr_1fr]`}>
        <div className="aspect-video overflow-hidden bg-surface-deep md:aspect-auto md:min-h-65">{img('size-full', true)}</div>
        <div className="flex min-w-0 flex-col justify-center p-5 md:p-7">
          <Byline item={item} />
          <h2 className="mt-3 font-display text-[24px] font-bold leading-[1.15] tracking-tight text-balance md:text-[28px]">{item.title}</h2>
          {item.summary && <p className="mt-3 line-clamp-3 text-[14px] leading-relaxed text-ink-mid">{item.summary}</p>}
          {href && (
            <span className="mt-4 inline-flex items-center gap-1 text-[12.5px] font-bold text-ink group-hover:underline">
              Read at {item.source ?? 'the source'} <ArrowUpRight size={14} />
            </span>
          )}
        </div>
      </Tag>
    );
  }

  // 사진이 있으면 위에, 없으면 제목이 카드의 전부 — 맨 위 자리(row)에 사진 없이 오면 글자를 더 키운다
  const big = shape === 'row';
  return (
    <Tag ref={ref as never} {...linkProps} className={`${shell} flex flex-col`}>
      {image && (
        <div className={`overflow-hidden bg-surface-deep ${shape === 'wide' ? 'aspect-video' : 'aspect-4/3'}`}>{img('size-full')}</div>
      )}
      <div className={`flex flex-1 flex-col ${big ? 'p-6 md:p-8' : 'p-4'}`}>
        <Byline item={item} />
        <h2 className={`mt-2 font-display font-bold tracking-tight ${big ? 'text-[24px] leading-[1.15] text-balance md:text-[30px]' : image ? 'line-clamp-3 text-[17px] leading-snug' : 'line-clamp-4 text-[19px] leading-snug'}`}>
          {item.title}
        </h2>
        {item.summary && <p className={`mt-2 text-ink-mid ${big ? 'line-clamp-3 text-[14px] leading-relaxed' : 'line-clamp-2 text-[13px] leading-relaxed'}`}>{item.summary}</p>}
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
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(true);
  const [failed, setFailed] = useState(false);
  const [moreFailed, setMoreFailed] = useState(false); // 추가 로딩 실패 — "끝까지 읽음" 과는 다른 상태다
  const [attempt, setAttempt] = useState(0);
  const sentinel = useRef<HTMLDivElement>(null);
  // 요청 세대 — 탭이 바뀌면 올라간다. 늦게 도착한 이전 탭의 응답은 세대가 달라서 버려진다.
  const gen = useRef(0);

  // 탭을 닫거나 떠날 때 모아 둔 신호를 흘리지 않는다
  useEffect(() => {
    const bye = () => flush(true);
    window.addEventListener('pagehide', bye);
    return () => { window.removeEventListener('pagehide', bye); flush(true); };
  }, []);
  const busy = useRef(false);

  // 종류가 바뀌면 처음부터 — offset 은 지금 가진 개수로 계산한다 (별도 상태를 두면 둘이 어긋난다)
  useEffect(() => {
    let alive = true;
    const mine = ++gen.current; // 이 effect 의 세대 — 진행 중이던 loadMore 는 여기서 무효가 된다
    busy.current = true;
    setLoading(true);
    setFailed(false);
    setMoreFailed(false);
    setItems([]);
    fetch(`/api/trends?kind=${kind}&anon=${encodeURIComponent(anonId())}&limit=${PAGE}`)
      .then(async (r) => { if (!r.ok) throw new Error(String(r.status)); return (await r.json()) as WirePage; })
      .then((page) => {
        if (!alive || gen.current !== mine) return;
        setItems(page.items);
        setHasMore(page.hasMore);
      })
      .catch(() => { if (alive && gen.current === mine) setFailed(true); })
      .finally(() => { if (alive && gen.current === mine) { setLoading(false); busy.current = false; } });
    return () => { alive = false; };
  }, [kind, attempt]);

  // 끝에 닿으면 다음 장 — 버튼도 남겨 둔다 (스크롤 감지가 안 되는 환경이 있다)
  useEffect(() => {
    const el = sentinel.current;
    if (!el || !hasMore || loading || moreFailed) return; // 실패 뒤엔 자동으로 다시 두드리지 않는다 — 버튼으로

    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) void loadMore();
    }, { rootMargin: '600px 0px' });
    io.observe(el);
    return () => io.disconnect();
    // items.length 가 바뀔 때마다 다시 붙인다 — 한 장 받은 뒤에도 끝에 닿아 있으면 곧장 다음 장
  }, [hasMore, loading, moreFailed, items.length]);

  async function loadMore() {
    if (busy.current || !hasMore) return;
    busy.current = true;
    setMoreFailed(false);
    const mine = gen.current; // 요청을 보낸 시점의 탭 세대
    try {
      // offset 이 아니라 '이미 가진 것' 을 보낸다 — 그새 순서가 바뀌어도 중복·누락 없이 다음 장을 받는다
      const exclude = items.slice(-400).map((i) => i.id).join(',');
      const r = await fetch(`/api/trends?kind=${kind}&anon=${encodeURIComponent(anonId())}&exclude=${exclude}&limit=${PAGE}`);
      if (!r.ok) throw new Error(String(r.status));
      const page = (await r.json()) as WirePage;
      if (gen.current !== mine) return; // 그새 탭이 바뀌었다 — 이 응답은 다른 목록의 것이다
      setItems((prev) => {
        const seen = new Set(prev.map((i) => i.id));
        return [...prev, ...page.items.filter((i) => !seen.has(i.id))];
      });
      setHasMore(page.hasMore);
    } catch {
      // 실패는 "끝까지 읽음" 이 아니다 — 목록·커서·hasMore 는 그대로 두고 다시 시도할 수 있게 한다
      if (gen.current === mine) setMoreFailed(true);
    } finally {
      if (gen.current === mine) busy.current = false;
    }
  }

  return (
    <main className="mt-8">
      <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-4">
        <h1 className="font-display text-[32px] font-bold leading-tight tracking-tight">News</h1>
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

      {/* 6칸 격자: 위에 한 장 크게, 아래는 3열 — 가끔 2열 한 쌍 */}
      <div className="mt-6 grid gap-5 sm:grid-cols-2 lg:grid-cols-6">
        {items.map((item, i) => <Card key={item.id} item={item} shape={shapeFor(kind, i)} />)}
        {loading && Array.from({ length: 6 }, (_, i) => (
          <div key={`s${i}`} className={`h-56 animate-pulse rounded-2xl bg-surface-deep/60 ${SPAN[i === 0 ? 'row' : 'tile']}`} />
        ))}
      </div>

      <div ref={sentinel} className="mt-8 flex flex-col items-center gap-2">
        {moreFailed && <p className="text-[13px] text-ink-soft">Couldn’t load more just now.</p>}
        {!loading && hasMore && (
          <button onClick={() => void loadMore()} className="rounded-full border border-hairline px-5 py-2 text-[13px] font-bold text-ink-mid hover:bg-surface">
            {moreFailed ? 'Try again' : 'More stories'}
          </button>
        )}
        {!loading && !hasMore && items.length > 0 && (
          <p className="font-mono text-[10.5px] uppercase tracking-widest text-ink-faint">You’re up to date</p>
        )}
      </div>
    </main>
  );
}
