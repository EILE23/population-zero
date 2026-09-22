'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { Clapperboard, Dices, ImagePlus, Paintbrush } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { Avatar, Badge } from '@/components/ui';
import { memeHref, type MemeKind } from '@/lib/memes';
import { VoteButton } from './VoteButton';
import { MediaCard } from './MediaCard';
import { MemeUpload } from './MemeUpload';

export interface WallRow { id: number; kind: MemeKind; png: string; thumb: string | null; image: string; top: string; bottom?: string; who: string; is_ai: number; avatar: string | null; votes: number; voted?: number; remixes: number; created_at: string }
export type Sort = 'new' | 'top' | 'gif' | 'video';
const TABS: { key: Sort; label: string }[] = [{ key: 'new', label: 'New' }, { key: 'top', label: 'Top' }, { key: 'gif', label: 'GIFs' }, { key: 'video', label: 'Videos' }];

/**
 * 벽 — 탭(New·Top·GIFs·Videos), 올리기 상자(그 자리에서 펼침), 끝까지 내리면 더 받는다(/api/memes).
 * 서버가 첫 40장을 그려 주고(검색엔진·첫 화면), 그 뒤는 여기서 이어 받는다. 카드 클릭은 영구링크.
 * 휴대폰에선 한 열 — 두 열이면 카드가 160px 이라 글자 많은 짤을 읽을 수 없다(실측).
 */
export function Wall({ initial, sort, signedIn }: { initial: WallRow[]; sort: Sort; signedIn: boolean }) {
  const [rows, setRows] = useState(initial);
  const [done, setDone] = useState(initial.length < 40);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [post, setPost] = useState(false);
  const more = useRef<HTMLDivElement>(null);
  useEffect(() => { setRows(initial); setDone(initial.length < 40); setError(''); }, [initial]);

  const load = async () => {
    if (busy || done || rows.length === 0) return;
    setBusy(true); setError('');
    try {
      const q = new URLSearchParams({ sort, before: String(rows[rows.length - 1].id), offset: String(rows.length) });
      const res = await fetch(`/api/memes?${q}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const d = (await res.json()) as { memes?: WallRow[] };
      const got = d.memes ?? [];
      const next = got.filter((m) => !rows.some((r) => r.id === m.id));
      setRows((r) => [...r, ...next]);
      if (got.length < 40) setDone(true); // 진짜 끝 — 오류는 끝이 아니다(아래 catch)
    } catch {
      setError('Could not load more. Try again.'); // busy 에 갇히거나 "끝" 으로 오해하지 않게
    } finally { setBusy(false); }
  };
  useEffect(() => {
    const el = more.current; if (!el) return;
    const io = new IntersectionObserver((es) => { if (es.some((e) => e.isIntersecting) && !error) void load(); }, { rootMargin: '600px' });
    io.observe(el); return () => io.disconnect();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rows, done, busy, sort, error]);

  return (
    <div>
      <div className="mt-6 flex flex-wrap items-center gap-2">
        <nav className="flex gap-1 rounded-full border border-hairline bg-paper p-1 text-[12.5px] font-bold" aria-label="Sort">
          {TABS.map((t) => <Link key={t.key} href={t.key === 'new' ? '/memes' : `/memes?sort=${t.key}`} aria-current={t.key === sort ? 'page' : undefined} className={`rounded-full px-3 py-1 ${t.key === sort ? 'bg-ink text-paper' : 'text-ink-mid hover:text-ink'}`}>{t.label}</Link>)}
        </nav>
        <div className="ml-auto flex flex-wrap gap-2">
          <button onClick={() => setPost((v) => !v)} className={`${post ? BUTTON.primary : BUTTON.ghost} inline-flex items-center gap-1.5`} aria-expanded={post}><ImagePlus size={14} aria-hidden /> Post</button>
          <Link href="/memes/new" className={`${BUTTON.ghost} inline-flex items-center gap-1.5`}><Paintbrush size={14} aria-hidden /> Make one</Link>
          <Link href="/memes/new?roll=1" className={`${BUTTON.ghost} inline-flex items-center gap-1.5`}><Dices size={14} aria-hidden /> Random meme</Link>
          <Link href="/memes/cut" className={`${BUTTON.ghost} hidden items-center gap-1.5 sm:inline-flex`}><Clapperboard size={14} aria-hidden /> Short video</Link>
        </div>
      </div>
      {post && <div className="mt-3"><MemeUpload signedIn={signedIn} /></div>}

      {rows.length === 0 ? (
        <p className="mt-12 text-[14px] text-ink-soft">Nothing here yet.</p>
      ) : (
        <ul className="mt-5 columns-1 gap-4 sm:columns-2 md:columns-3 lg:columns-4 [&>li]:mb-5">
          {rows.map((m) => (
            <li key={m.id} className="break-inside-avoid">
              <Link href={memeHref(m.id)} className="group block overflow-hidden rounded-xl border border-hairline bg-paper transition-shadow duration-300 hover:shadow-[0_6px_24px_-8px_rgba(0,0,0,0.35)] focus-visible:shadow-[0_6px_24px_-8px_rgba(0,0,0,0.35)]">
                <MediaCard kind={m.kind} png={m.png} thumb={m.thumb} image={m.image} alt={[m.top, m.bottom].filter(Boolean).join(' / ')} />
              </Link>
              {m.top && m.kind !== 'image' ? <p className="mt-1.5 px-0.5 text-[13px] font-semibold leading-snug">{m.top}</p> : null}
              {/* 작성자는 줄어들고 잘리며, 배지·표는 절대 밀리지 않는다 — 긴 핸들이 카드 폭을 넘던 실측 */}
              <div className="mt-1.5 flex items-center gap-2 px-0.5 text-[12px] text-ink-soft">
                <Link href={`/@${m.who.toLowerCase().replace(/ /g, '-')}`} className="inline-flex min-w-0 items-center gap-1.5 font-semibold text-ink-mid hover:underline">
                  <Avatar handle={m.who} size={18} isHuman={!m.is_ai} src={m.avatar} /><span className="truncate">{m.who}</span>
                </Link>
                {m.is_ai ? <span className="shrink-0"><Badge variant="resident">AI</Badge></span> : null}
                {m.remixes > 0 && <span className="shrink-0">· {m.remixes} remix{m.remixes > 1 ? 'es' : ''}</span>}
                <span className="ml-auto shrink-0"><VoteButton id={m.id} initial={m.votes} initialOn={!!m.voted} signedIn={signedIn} back={sort === 'new' ? '/memes' : `/memes?sort=${sort}`} /></span>
              </div>
            </li>
          ))}
        </ul>
      )}
      <div ref={more} className="h-8" />
      {error && <p role="alert" className="mb-3 text-center text-[12.5px] font-semibold text-accent-deep">{error}</p>}
      {!done && rows.length > 0 && <div className="mb-8 text-center"><button onClick={() => void load()} disabled={busy} className={`${BUTTON.ghost}`}>{busy ? 'Loading…' : error ? 'Retry' : 'More'}</button></div>}
      {done && rows.length >= 40 && <p className="mb-8 text-center font-mono text-[11px] text-ink-soft">That is all of it.</p>}
    </div>
  );
}
