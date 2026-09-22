'use client';
import { useEffect, useId, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Clapperboard, ImagePlus, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { youtubeId } from '@/lib/memes';
import { thumbFromFile } from '@/lib/thumb';

/**
 * 그냥 올리기 — 그림 한 장, GIF 한 장, 유튜브 링크 하나. 만들기(그림판)와 나란히 있고 더 자주 쓰인다.
 * 파일은 /api/upload(kind=meme, 8MB) 로 먼저 올리고 주소만 /api/memes 에 넘긴다.
 */
/** 영상 파일의 첫 프레임(0.5초) — 포스터·공유 미리보기용 PNG */
function firstFrame(file: File): Promise<Blob | null> {
  return new Promise((ok) => {
    const v = document.createElement('video'); v.muted = true; v.playsInline = true; v.preload = 'auto';
    v.src = URL.createObjectURL(file);
    v.onloadeddata = () => { v.currentTime = Math.min(0.5, (v.duration || 1) / 2); };
    v.onseeked = () => {
      const c = document.createElement('canvas'); c.width = v.videoWidth; c.height = v.videoHeight;
      c.getContext('2d')?.drawImage(v, 0, 0); c.toBlob((b) => ok(b), 'image/png');
    };
    v.onerror = () => ok(null);
  });
}

export function MemeUpload({ signedIn }: { signedIn: boolean }) {
  const router = useRouter();
  const [file, setFile] = useState<File | null>(null);
  const [video, setVideo] = useState('');
  const [caption, setCaption] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  // 미리보기 주소는 파일이 바뀔 때만 만들고, 바뀌면 이전 것을 놓아 준다 — 렌더마다 만들면 입력할 때마다 새 blob 이 쌓였다
  const [preview, setPreview] = useState<string | null>(null);
  useEffect(() => {
    if (!file) { setPreview(null); return; }
    const u = URL.createObjectURL(file); setPreview(u);
    return () => URL.revokeObjectURL(u);
  }, [file]);
  const fileId = useId();
  const yt = youtubeId(video);

  const post = async () => {
    if (!signedIn) { setMessage('Log in to post.'); return; }
    if (!file && !video.trim()) { setMessage('Pick a picture or paste a YouTube link.'); return; }
    if (video.trim() && !yt) { setMessage('That does not look like a YouTube link.'); return; }
    setBusy(true); setMessage('');
    try {
      let png: string | undefined, clip: string | undefined, thumb: string | undefined;
      const isVideo = !!file && file.type.startsWith('video/');
      const send = async (f: File, kind: 'meme' | 'clip') => {
        const body = new FormData(); body.append('image', f); body.append('kind', kind);
        const d = await (await fetch('/api/upload', { method: 'POST', body })).json() as { url?: string; error?: string };
        if (!d.url) setMessage(d.error === 'upload failed (type/size)' ? (kind === 'clip' ? 'WebM or MP4 up to 12MB.' : 'PNG, JPG, WEBP or GIF up to 8MB.') : d.error ?? 'Upload failed.');
        return d.url;
      };
      // 벽용 작은 그림(480px WebP) — 실패해도 게시는 간다(벽이 원본을 쓴다)
      const sendThumb = async (blob: Blob | null) => (blob ? await send(new File([blob], blob.type === 'image/webp' ? 'thumb.webp' : 'thumb.jpg', { type: blob.type }), 'meme') : undefined);
      if (file && !yt) {
        if (isVideo) {
          // 내 영상 — 포스터는 브라우저가 첫 프레임을 찍는다
          clip = await send(file, 'clip'); if (!clip) { setBusy(false); return; }
          const posterBlob = await firstFrame(file);
          png = posterBlob ? await send(new File([posterBlob], 'poster.png', { type: 'image/png' }), 'meme') : undefined;
          if (!png) { setBusy(false); return; }
          thumb = await sendThumb(posterBlob ? await thumbFromFile(new File([posterBlob], 'p.png', { type: 'image/png' })) : null);
        } else {
          png = await send(file, 'meme'); if (!png) { setBusy(false); return; }
          thumb = await sendThumb(await thumbFromFile(file));
        }
      }
      const res = await fetch('/api/memes', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify(yt ? { video: video.trim(), caption } : clip ? { clip, png, thumb, caption } : { png, thumb, caption }),
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
        {/* input 은 화면에서만 숨긴다(sr-only) — display:none 이면 키보드로 닿을 수 없다. label 이 눌리는 면이다 */}
        <label htmlFor={fileId} className={`${BUTTON.ghost} inline-flex cursor-pointer items-center gap-1.5 focus-within:ring-2 focus-within:ring-accent`}>
          <ImagePlus size={14} aria-hidden /> {file ? file.name.slice(0, 24) : 'Picture, GIF or video'}
        </label>
        <input id={fileId} type="file" accept="image/png,image/jpeg,image/webp,image/gif,video/mp4,video/webm" className="sr-only" aria-label="Choose a picture, GIF or video"
          onChange={(e) => { const f = e.target.files?.[0] ?? null; e.target.value = ''; setFile(f); if (f) setVideo(''); }} />
        <div className="relative">
          <Clapperboard size={14} aria-hidden className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-ink-soft" />
          <input value={video} onChange={(e) => { setVideo(e.target.value); if (e.target.value) setFile(null); }} placeholder="or a YouTube link (watch, shorts, youtu.be)" aria-label="YouTube link"
            className="w-full rounded-lg border border-hairline bg-surface py-1.5 pl-8 pr-2.5 text-[13px] outline-none focus:border-ink" />
        </div>
      </div>
      {(preview || yt) && (
        <div className="mt-2 overflow-hidden rounded-lg border border-hairline bg-[#e9e6e8]">
          {file?.type.startsWith('video/') && preview ? (
            <video src={preview} muted loop autoPlay playsInline className="mx-auto max-h-72" />
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={preview ?? `https://i.ytimg.com/vi/${yt}/hqdefault.jpg`} alt="" className="mx-auto max-h-72 object-contain" />
          )}
        </div>
      )}
      <div className="mt-2 flex gap-2">
        <input value={caption} onChange={(e) => setCaption(e.target.value)} maxLength={120} placeholder="Caption (optional)" aria-label="Caption"
          className="min-w-0 flex-1 rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[13px] outline-none focus:border-ink" />
        <button onClick={() => void post()} disabled={busy} className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
          <Upload size={14} aria-hidden /> {busy ? 'Posting…' : 'Post'}
        </button>
      </div>
      {message && <p role="alert" className="mt-2 text-[12.5px] font-semibold text-accent-deep">{message}</p>}
      {!signedIn && <p className="mt-2 text-[11.5px] text-ink-soft">Posting needs an account. Making and downloading below does not.</p>}
    </section>
  );
}
