'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Clapperboard, ImagePlus, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { youtubeId } from '@/lib/memes';

/**
 * 그냥 올리기 — 그림 한 장, GIF 한 장, 유튜브 링크 하나. 만들기(그림판)와 나란히 있고 더 자주 쓰인다.
 * 파일은 /api/upload(kind=meme, 8MB) 로 먼저 올리고 주소만 /api/memes 에 넘긴다.
 */
export function MemeUpload({ signedIn }: { signedIn: boolean }) {
  const router = useRouter();
  const [file, setFile] = useState<File | null>(null);
  const [video, setVideo] = useState('');
  const [caption, setCaption] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const preview = file ? URL.createObjectURL(file) : null;
  const yt = youtubeId(video);

  const post = async () => {
    if (!signedIn) { setMessage('Log in to post.'); return; }
    if (!file && !video.trim()) { setMessage('Pick a picture or paste a YouTube link.'); return; }
    if (video.trim() && !yt) { setMessage('That does not look like a YouTube link.'); return; }
    setBusy(true); setMessage('');
    try {
      let png: string | undefined;
      if (file && !yt) {
        const body = new FormData(); body.append('image', file); body.append('kind', 'meme');
        const d = await (await fetch('/api/upload', { method: 'POST', body })).json() as { url?: string; error?: string };
        if (!d.url) { setMessage(d.error === 'upload failed (type/size)' ? 'PNG, JPG, WEBP or GIF up to 8MB.' : d.error ?? 'Upload failed.'); setBusy(false); return; }
        png = d.url;
      }
      const res = await fetch('/api/memes', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify(yt ? { video: video.trim(), caption } : { png, caption }),
      });
      const d = await res.json() as { ok?: boolean; url?: string; message?: string };
      if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not post that.'); setBusy(false); return; }
      router.push(d.url!);
    } catch { setMessage('Could not post that.'); setBusy(false); }
  };

  return (
    <section className="rounded-xl border border-hairline bg-paper p-3 sm:p-4">
      <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Post one</p>
      <div className="mt-2 grid gap-2 sm:grid-cols-[auto_minmax(0,1fr)] sm:items-start">
        <label className={`${BUTTON.ghost} inline-flex cursor-pointer items-center gap-1.5`}>
          <ImagePlus size={14} aria-hidden /> {file ? file.name.slice(0, 24) : 'Picture or GIF'}
          <input type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="hidden"
            onChange={(e) => { const f = e.target.files?.[0] ?? null; e.target.value = ''; setFile(f); if (f) setVideo(''); }} />
        </label>
        <div className="relative">
          <Clapperboard size={14} aria-hidden className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-soft" />
          <input value={video} onChange={(e) => { setVideo(e.target.value); if (e.target.value) setFile(null); }} placeholder="or a YouTube link (watch, shorts, youtu.be)"
            className="w-full rounded-lg border border-hairline bg-surface py-1.5 pl-8 pr-2.5 text-[13px] outline-none focus:border-ink" />
        </div>
      </div>
      {(preview || yt) && (
        <div className="mt-2 overflow-hidden rounded-lg border border-hairline bg-[#e9e6e8]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={preview ?? `https://i.ytimg.com/vi/${yt}/hqdefault.jpg`} alt="" className="mx-auto max-h-72 object-contain" />
        </div>
      )}
      <div className="mt-2 flex gap-2">
        <input value={caption} onChange={(e) => setCaption(e.target.value)} maxLength={120} placeholder="Caption (optional)"
          className="min-w-0 flex-1 rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[13px] outline-none focus:border-ink" />
        <button onClick={() => void post()} disabled={busy} className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
          <Upload size={14} aria-hidden /> {busy ? 'Posting…' : 'Post'}
        </button>
      </div>
      {message && <p role="alert" className="mt-2 text-[12.5px] font-semibold text-accent-deep">{message}</p>}
    </section>
  );
}
