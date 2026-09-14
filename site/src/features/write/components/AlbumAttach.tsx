'use client';
import { useEffect, useState } from 'react';

type AlbumLite = { album_id: number; id: number; title: string; cover: string | null; shot_count: number; handle: string };

/**
 * 글에 앨범 붙이기 — 앱의 AlbumPicker 와 같은 일을 웹 에디터에서.
 * 내 앨범(/api/albums?mine=1)을 격자로 보여주고 하나를 고르면 hidden album_id 로 폼에 실린다.
 * 서버(/api/posts)는 이 글이 그 앨범을 '공유' 하는 것으로 저장하고, 커버가 없으면 앨범 첫 사진을 커버로 쓴다.
 * 남의 앨범 공유는 그 앨범이 있는 글에서 시작하는 게 맞다(출처가 거기 있으니까) — 여기서는 내 것만.
 */
export function AlbumAttach() {
  const [open, setOpen] = useState(false);
  const [albums, setAlbums] = useState<AlbumLite[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const [picked, setPicked] = useState<AlbumLite | null>(null);

  useEffect(() => {
    if (!open) return;
    let alive = true;
    setFailed(false);
    fetch('/api/albums?mine=1&limit=30', { cache: 'no-store' })
      .then(async (r) => { if (!r.ok) throw new Error(String(r.status)); return (await r.json()) as AlbumLite[]; })
      .then((list) => { if (alive) setAlbums(list); })
      .catch(() => { if (alive) { setAlbums(null); setFailed(true); } });
    return () => { alive = false; };
  }, [open, attempt]);

  return (
    <div className="mb-4">
      {picked && <input type="hidden" name="album_id" value={picked.album_id} />}
      {picked ? (
        <div className="flex items-center gap-3 rounded-xl border border-hairline p-2">
          {picked.cover
            ? <img src={picked.cover} alt="" className="h-14 w-14 shrink-0 rounded-lg object-cover" />
            : <div className="h-14 w-14 shrink-0 rounded-lg bg-surface-deep" aria-hidden />}
          <div className="min-w-0 flex-1">
            <div className="truncate text-[13px] font-semibold">{picked.title?.trim() || 'Untitled album'}</div>
            <div className="text-[12px] text-ink-soft">{picked.shot_count} {picked.shot_count === 1 ? 'photo' : 'photos'} · shared into this post</div>
          </div>
          <button type="button" onClick={() => setOpen(true)} className="rounded-full px-3 py-1.5 text-[12px] font-bold text-ink-mid hover:bg-surface">Change</button>
          <button type="button" onClick={() => setPicked(null)} className="rounded-full px-3 py-1.5 text-[12px] font-bold text-ink-mid hover:bg-surface">Remove</button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          className="inline-flex cursor-pointer items-center gap-2 rounded-full border border-dashed border-hairline px-4 py-2 text-[13px] font-semibold text-ink-mid hover:bg-surface"
        >
          <span aria-hidden>▤</span> Attach an album
        </button>
      )}

      {open && (
        <div role="dialog" aria-label="Choose an album" className="mt-3 rounded-xl border border-hairline bg-paper p-3">
          <div className="mb-2 flex items-center justify-between">
            <span className="font-mono text-[10.5px] font-bold uppercase tracking-widest text-ink-soft">Your albums</span>
            <button type="button" onClick={() => setOpen(false)} className="rounded-full px-2 py-1 text-[12px] font-bold text-ink-soft hover:text-ink">Close</button>
          </div>
          {failed ? (
            <div className="py-6 text-center text-[13px] text-ink-soft">
              Could not load your albums.
              <button type="button" onClick={() => setAttempt((n) => n + 1)} className="ml-2 rounded-full border border-hairline px-3 py-1 text-[12px] font-bold text-ink-mid hover:bg-surface">Try again</button>
            </div>
          ) : albums == null ? (
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-5">
              {Array.from({ length: 5 }, (_, i) => <div key={i} className="aspect-square animate-pulse rounded-lg bg-surface-deep/60" />)}
            </div>
          ) : albums.length === 0 ? (
            <p className="py-6 text-center text-[13px] text-ink-soft">No albums yet — post photos from the app’s Album tab first.</p>
          ) : (
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-5">
              {albums.map((a) => (
                <button
                  key={a.album_id}
                  type="button"
                  onClick={() => { setPicked(a); setOpen(false); }}
                  className="group text-left"
                  aria-pressed={picked?.album_id === a.album_id}
                >
                  <div className={`relative aspect-square overflow-hidden rounded-lg bg-surface-deep ring-2 ${picked?.album_id === a.album_id ? 'ring-accent' : 'ring-transparent group-hover:ring-hairline'}`}>
                    {a.cover && <img src={a.cover} alt="" className="size-full object-cover" loading="lazy" />}
                    {a.shot_count > 1 && <span className="absolute right-1.5 top-1.5 rounded bg-ink/60 px-1.5 py-0.5 text-[10px] font-bold text-paper">{a.shot_count}</span>}
                  </div>
                  <div className="mt-1 truncate text-[11.5px] text-ink-mid">{a.title?.trim() || 'Untitled'}</div>
                </button>
              ))}
            </div>
          )}
          <p className="mt-2 text-[11px] text-ink-soft">Only your own albums. To share someone else’s, open the post it lives in.</p>
        </div>
      )}
    </div>
  );
}
