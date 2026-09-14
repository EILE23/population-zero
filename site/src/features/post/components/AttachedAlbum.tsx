'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { X, Images } from 'lucide-react';
import { handleSlug } from '@/lib/content';

/**
 * 글에 붙어 온 남의(또는 내) 앨범 — 본문 안에 사진을 풀어 놓지 않는다.
 * 앨범은 글의 일부가 아니라 '딸려 온 물건' 이다: 본문 아래 카드 하나로 떼어 두고, 누르면 모달로 열린다.
 * (사진을 본문 사이에 늘어놓으면 글쓴이가 찍은 사진처럼 읽히고, 긴 앨범이면 글이 사진 뒤로 밀린다.)
 */
export function AttachedAlbum({ images, owner, originPostId }: { images: string[]; owner: string | null; originPostId: number | null }) {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    window.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { window.removeEventListener('keydown', onKey); document.body.style.overflow = prev; };
  }, [open]);
  if (!images.length) return null;

  return (
    <aside aria-label="Attached album" className="my-8 border-t border-hairline pt-5">
      <div className="mb-3 font-mono text-[10.5px] font-bold uppercase tracking-widest text-ink-soft">Attached album</div>
      <button type="button" onClick={() => setOpen(true)} className="group flex w-full items-center gap-4 rounded-2xl border border-hairline bg-paper p-3 text-left transition-shadow hover:shadow-[0_2px_12px_rgba(0,0,0,0.08)]">
        <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-xl bg-surface-deep">
          <img src={images[0]} alt="" className="size-full object-cover" loading="lazy" />
          {images.length > 1 && (
            <span className="absolute bottom-1 right-1 rounded bg-ink-black/60 px-1.5 py-0.5 font-mono text-[10px] font-bold text-paper">{images.length}</span>
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5 text-[14px] font-bold"><Images size={15} aria-hidden /> Album · {images.length} {images.length === 1 ? 'shot' : 'shots'}</div>
          <div className="mt-1 text-[12.5px] text-ink-soft">
            by {owner ? <Link className="text-ink hover:underline" href={`/@${handleSlug(owner)}`} onClick={(e) => e.stopPropagation()}>{owner}</Link> : 'someone'}
            {originPostId && <> · <Link className="text-ink hover:underline" href={`/p/${originPostId}`} onClick={(e) => e.stopPropagation()}>original post</Link></>}
          </div>
        </div>
        <span className="shrink-0 rounded-full border border-hairline px-3.5 py-1.5 text-[12.5px] font-bold text-ink-mid group-hover:bg-surface">Open</span>
      </button>

      {open && (
        <div role="dialog" aria-modal="true" aria-label="Album" className="fixed inset-0 z-50 flex flex-col bg-ink-black/95" onClick={() => setOpen(false)}>
          <div className="flex shrink-0 items-center justify-between px-4 py-3 text-paper">
            <span className="font-mono text-[11px] uppercase tracking-widest">Album · {images.length} {images.length === 1 ? 'shot' : 'shots'}{owner ? ` · ${owner}` : ''}</span>
            <button type="button" aria-label="Close" onClick={() => setOpen(false)} className="rounded-full p-2 hover:bg-paper/10"><X size={20} /></button>
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto px-4 pb-8" onClick={(e) => e.stopPropagation()}>
            <div className="mx-auto flex max-w-4xl flex-col gap-3">
              {images.map((src, i) => (
                <div key={src} className="relative">
                  <img src={src} alt="" loading={i === 0 ? 'eager' : 'lazy'} className="mx-auto max-h-[85svh] w-auto max-w-full rounded-lg object-contain" />
                  {images.length > 1 && <span className="absolute right-2 top-2 rounded-full bg-ink-black/60 px-2 py-0.5 font-mono text-[10px] font-bold text-paper tabular-nums">{i + 1}/{images.length}</span>}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
