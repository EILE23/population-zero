'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowDown, ArrowUp, Clapperboard, Dices, Download, Play, Square, Trash2, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { FONTS, type MemeText } from '@/lib/memes';
import { drawMemeText, FONT_CSS, FONT_LABEL } from '@/lib/meme-draw';

/**
 * 릴 편집기 — 사람이 주민과 같은 재료(퍼블릭 도메인 필름의 샷)로 세로 영상을 자른다.
 *
 * 샷 격자에서 고르면 타임라인에 붙고, 컷마다 길이·시작점·자막·효과를 정한다. 미리보기와 녹화는 같은 엔진이다:
 * 숨은 <video>(우리 프록시 경유 — 그래야 캔버스에 그릴 수 있다)를 컷 시작점으로 찾아가 재생하며 캔버스에 프레임을 그리고,
 * 자막은 짤 편집기와 같은 글꼴·코드로 얹는다. 녹화는 캔버스 스트림 + 영상 소리(WebAudio) 를 MediaRecorder 로 받는다.
 * 서버는 결과 파일만 받는다(서버비 0). 주민 렌더(patrol/reels.py)와 같은 효과 어휘를 쓴다.
 */
interface Shot { idx: number; start: number; dur: number }
interface Film { id: number; ident: string; title: string; descr: string; year: number | null; dur: number; thumb: string; sheet: string; cols: number; shots: Shot[] }
type Fx = 'zoom' | 'punch' | 'shake' | 'bw' | 'deepfry' | 'slowmo' | 'freeze';
interface Cut { key: number; film: Film; shot: Shot; off: number; dur: number; caption: string; pos: 'top' | 'center' | 'bottom'; font: MemeText['font']; fx: Fx[] }
const FXS: Fx[] = ['zoom', 'punch', 'shake', 'bw', 'deepfry', 'slowmo', 'freeze'];
const W = 720, H = 1280, TILE_W = 240, TILE_H = 135;
const MAX_TOTAL = 35;

export function ReelEditor({ signedIn }: { signedIn: boolean }) {
  const router = useRouter();
  const [films, setFilms] = useState<Film[]>([]);
  const [cuts, setCuts] = useState<Cut[]>([]);
  const [sel, setSel] = useState<number | null>(null);
  const [title, setTitle] = useState('');
  const [state, setState] = useState<'idle' | 'playing' | 'recording' | 'posting'>('idle');
  const [progress, setProgress] = useState(0);
  const [out, setOut] = useState<{ url: string; video: Blob; poster: Blob; mime: string } | null>(null);
  const [message, setMessage] = useState('');
  const canvas = useRef<HTMLCanvasElement>(null);
  const videos = useRef(new Map<number, HTMLVideoElement>());
  const sources = useRef(new Map<number, MediaElementAudioSourceNode>());
  const audio = useRef<{ ctx: AudioContext; dest: MediaStreamAudioDestinationNode } | null>(null);
  const stop = useRef(false);
  const keyRef = useRef(1);

  const load = async () => {
    const d = await (await fetch('/api/clips?n=6', { cache: 'no-store' })).json() as { films: Film[] };
    setFilms(d.films);
  };
  useEffect(() => { void load(); }, []);

  const total = cuts.reduce((a, c) => a + c.dur * (c.fx.includes('slowmo') ? 2 : 1) + (c.fx.includes('freeze') ? 1 : 0), 0);

  const add = (film: Film, shot: Shot) => {
    if (total >= MAX_TOTAL) { setMessage(`${MAX_TOTAL}s is the ceiling.`); return; }
    const c: Cut = { key: keyRef.current++, film, shot, off: 0, dur: Math.min(3, shot.dur), caption: '', pos: 'bottom', font: 'impact', fx: [] };
    setCuts((cs) => [...cs, c]); setSel(cuts.length);
  };
  const patch = (p: Partial<Cut>) => { if (sel === null) return; setCuts((cs) => cs.map((c, i) => (i === sel ? { ...c, ...p } : c))); };
  const move = (i: number, d: -1 | 1) => { const j = i + d; if (j < 0 || j >= cuts.length) return; const cs = [...cuts]; [cs[i], cs[j]] = [cs[j], cs[i]]; setCuts(cs); setSel(j); };
  const remove = (i: number) => { setCuts((cs) => cs.filter((_, k) => k !== i)); setSel(null); };

  /** 필름의 <video> — 프록시 경유, 처음 한 번 만든다 */
  const videoOf = (film: Film) => {
    let v = videos.current.get(film.id);
    if (!v) {
      v = document.createElement('video'); v.src = `/api/clips/stream?f=${film.id}`; v.preload = 'auto'; v.playsInline = true; v.muted = false; v.volume = 1;
      v.style.display = 'none'; document.body.appendChild(v); videos.current.set(film.id, v);
    }
    return v;
  };
  const seek = (v: HTMLVideoElement, t: number) => new Promise<void>((ok) => {
    if (Math.abs(v.currentTime - t) < 0.05 && v.readyState >= 2) return ok();
    const done = () => { v.removeEventListener('seeked', done); ok(); };
    v.addEventListener('seeked', done); v.currentTime = t;
  });

  /** 한 프레임 — 뒤엔 흐린 같은 장면, 앞엔 폭 맞춤, 효과, 자막. u 는 컷 진행도 0~1 */
  const drawFrame = (ctx: CanvasRenderingContext2D, v: HTMLVideoElement, cut: Cut, u: number, t: number) => {
    const vw = v.videoWidth || 4, vh = v.videoHeight || 3;
    ctx.save();
    ctx.filter = 'blur(26px) brightness(0.45)';
    const s = Math.max(W / vw, H / vh) * 1.15; ctx.drawImage(v, (W - vw * s) / 2, (H - vh * s) / 2, vw * s, vh * s);
    ctx.restore();
    const fit = Math.min(W / vw, H / vh); const fw = vw * fit, fh = vh * fit;
    let z = 1, ox = 0, oy = 0;
    if (cut.fx.includes('zoom')) z = 1 + 0.22 * u;
    if (cut.fx.includes('punch')) z = u < 0.12 ? 1 + 2 * u : 1.24;
    if (cut.fx.includes('shake')) { ox = 8 * Math.sin(37 * t); oy = 8 * Math.cos(41 * t); }
    ctx.save();
    ctx.translate(W / 2 + ox, H / 2 + oy); ctx.scale(z, z); ctx.translate(-W / 2, -H / 2);
    const filters: string[] = [];
    if (cut.fx.includes('bw')) filters.push('grayscale(1)');
    if (cut.fx.includes('deepfry')) filters.push('contrast(1.8) saturate(2.6)');
    ctx.filter = filters.join(' ') || 'none';
    ctx.drawImage(v, (W - fw) / 2, (H - fh) / 2, fw, fh);
    ctx.restore();
    if (cut.caption) {
      const y = cut.pos === 'top' ? 0.1 : cut.pos === 'center' ? 0.5 : 0.88;
      const p = Math.min(1, u * cut.dur / 0.25);
      ctx.save(); ctx.globalAlpha = p;
      drawMemeText(ctx, { t: cut.caption, x: 0.5, y, size: 0.05, color: '#ffffff', stroke: '#000000', rot: 0, font: cut.font, bg: 'none' }, W, H);
      ctx.restore();
    }
  };

  /** 타임라인 재생 — record 면 녹화까지. 컷마다 찾아가서 재생하며 그린다 */
  const run = async (record: boolean) => {
    if (!cuts.length) { setMessage('Add a shot first.'); return; }
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    setState(record ? 'recording' : 'playing'); setMessage(''); stop.current = false; setOut(null);
    let rec: MediaRecorder | null = null; const chunks: Blob[] = []; let mime = '';
    let poster: Blob | null = null;
    if (record) {
      if (!audio.current) { const actx = new AudioContext(); audio.current = { ctx: actx, dest: actx.createMediaStreamDestination() }; }
      await audio.current.ctx.resume();
      for (const cut of cuts) {
        const v = videoOf(cut.film);
        if (!sources.current.has(cut.film.id)) { const src = audio.current.ctx.createMediaElementSource(v); src.connect(audio.current.dest); src.connect(audio.current.ctx.destination); sources.current.set(cut.film.id, src); }
      }
      mime = ['video/webm;codecs=vp9,opus', 'video/webm;codecs=vp8,opus', 'video/webm', 'video/mp4'].find((m) => MediaRecorder.isTypeSupported(m)) ?? '';
      if (!mime) { setMessage('This browser cannot record video.'); setState('idle'); return; }
      const stream = new MediaStream([...c.captureStream(30).getVideoTracks(), ...audio.current.dest.stream.getAudioTracks()]);
      rec = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 2_800_000, audioBitsPerSecond: 96_000 });
      rec.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      rec.start(250);
    }
    const t0 = performance.now(); let elapsed = 0;
    for (let i = 0; i < cuts.length && !stop.current; i++) {
      const cut = cuts[i]; const v = videoOf(cut.film);
      v.playbackRate = cut.fx.includes('slowmo') ? 0.5 : 1;
      await seek(v, cut.shot.start + cut.off);
      try { await v.play(); } catch { /* 자동재생 막힘 — 사용자 제스처 안이라 보통 된다 */ }
      const wall = cut.dur * (cut.fx.includes('slowmo') ? 2 : 1);
      const start = performance.now();
      await new Promise<void>((ok) => {
        const tick = () => {
          const u = (performance.now() - start) / 1000 / wall;
          if (u >= 1 || stop.current) return ok();
          drawFrame(ctx, v, cut, u, performance.now() / 1000);
          if (record && i === 0 && !poster && u > 0.3) c.toBlob((b) => { poster = b; }, 'image/png');
          setProgress((elapsed + u * wall) / total);
          requestAnimationFrame(tick);
        };
        tick();
      });
      v.pause();
      if (cut.fx.includes('freeze') && !stop.current) { // 마지막 프레임 1초 정지
        const start2 = performance.now();
        await new Promise<void>((ok) => { const tick = () => { if (performance.now() - start2 > 1000 || stop.current) return ok(); drawFrame(ctx, v, cut, 1, performance.now() / 1000); requestAnimationFrame(tick); }; tick(); });
      }
      elapsed += wall + (cut.fx.includes('freeze') ? 1 : 0);
    }
    void t0;
    if (rec) {
      await new Promise((r) => setTimeout(r, 300));
      const done = new Promise<void>((ok) => { rec!.onstop = () => ok(); });
      rec.stop(); await done;
      if (!poster) poster = await new Promise<Blob | null>((ok) => c.toBlob(ok, 'image/png'));
      if (!stop.current && poster) {
        const video = new Blob(chunks, { type: mime.split(';')[0] });
        setOut({ url: URL.createObjectURL(video), video, poster, mime: mime.split(';')[0] });
      }
    }
    setState('idle'); setProgress(0);
  };

  const post = async () => {
    if (!out) return;
    if (!signedIn) { setMessage('Log in to post. Downloading works without an account.'); return; }
    setState('posting');
    const send = async (f: File, kind: 'meme' | 'clip') => {
      const body = new FormData(); body.append('image', f); body.append('kind', kind);
      const d = await (await fetch('/api/upload', { method: 'POST', body })).json() as { url?: string; error?: string };
      if (!d.url) setMessage(d.error ?? 'Upload failed.');
      return d.url;
    };
    const ext = out.mime.includes('mp4') ? 'mp4' : 'webm';
    const clip = await send(new File([out.video], `reel.${ext}`, { type: out.mime }), 'clip');
    const png = clip ? await send(new File([out.poster], 'poster.png', { type: 'image/png' }), 'meme') : null;
    if (!clip || !png) { setState('idle'); return; }
    const style = { reel: { title, scenes: cuts.map((c) => ({ film: c.film.ident, shot: c.shot.idx, off: c.off, dur: c.dur, caption: c.caption, pos: c.pos, font: c.font, fx: c.fx })) } };
    const res = await fetch('/api/memes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ clip, png, caption: title, style }) });
    const d = await res.json() as { ok?: boolean; url?: string; message?: string };
    setState('idle');
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not post that.'); return; }
    router.push(d.url!);
  };

  const cur = sel !== null ? cuts[sel] : null;
  const tb = (on: boolean) => `inline-flex cursor-pointer items-center gap-1 rounded-md px-2 py-1 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'text-ink-mid hover:bg-surface'}`;
  const tile = (film: Film, shot: Shot, size = 1) => (
    <span className="block overflow-hidden rounded bg-black" style={{ width: TILE_W * size, height: TILE_H * size, backgroundImage: `url(${film.sheet})`, backgroundSize: `${TILE_W * film.cols * size}px auto`, backgroundPosition: `-${(shot.idx % film.cols) * TILE_W * size}px -${Math.floor(shot.idx / film.cols) * TILE_H * size}px` }} />
  );

  return (
    <div className="mt-5 grid gap-4 lg:grid-cols-[minmax(0,1fr)_22rem]">
      <div className="min-w-0">
        {/* ── 필름·샷 ── */}
        <div className="flex items-center justify-between">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Shots — click to add</p>
          <button onClick={() => void load()} className={`${BUTTON.ghost} inline-flex items-center gap-1.5 !py-1`}><Dices size={13} aria-hidden /> Other films</button>
        </div>
        <div className="mt-2 max-h-[52vh] space-y-4 overflow-y-auto rounded-xl border border-hairline bg-paper p-3">
          {films.map((f) => (
            <div key={f.id}>
              <p className="text-[13px] font-bold">{f.title} <span className="font-normal text-ink-soft">{f.year ?? ''}</span></p>
              <p className="text-[11.5px] text-ink-soft">{f.descr}</p>
              <div className="mt-1.5 flex flex-wrap gap-1">
                {f.shots.map((s) => (
                  <button key={s.idx} onClick={() => add(f, s)} title={`${s.dur.toFixed(1)}s`} className="cursor-pointer rounded border border-hairline hover:border-ink">
                    {tile(f, s, 0.5)}
                  </button>
                ))}
              </div>
            </div>
          ))}
          {films.length === 0 && <p className="text-[12.5px] text-ink-soft">Loading films…</p>}
        </div>

        {/* ── 타임라인 ── */}
        <p className="mt-4 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Timeline · {total.toFixed(1)}s</p>
        <div className="mt-2 flex gap-2 overflow-x-auto rounded-xl border border-hairline bg-paper p-2">
          {cuts.length === 0 && <p className="px-2 py-4 text-[12.5px] text-ink-soft">Nothing yet. Click shots above; they line up here in order.</p>}
          {cuts.map((c, i) => (
            <button key={c.key} onClick={() => setSel(i)} className={`shrink-0 rounded-lg border-2 p-1 text-left ${sel === i ? 'border-accent' : 'border-hairline'}`}>
              {tile(c.film, c.shot, 0.5)}
              <p className="mt-1 w-[120px] truncate text-[11px] font-bold">{c.caption || <span className="text-ink-soft">no caption</span>}</p>
              <p className="font-mono text-[10px] text-ink-soft">{c.dur.toFixed(1)}s {c.fx.join(' ')}</p>
            </button>
          ))}
        </div>
      </div>

      {/* ── 컷 설정 · 미리보기 · 녹화 ── */}
      <div className="flex flex-col gap-3">
        <div className="rounded-xl border border-hairline bg-paper p-3">
          {cur ? (
            <>
              <div className="flex items-center gap-1">
                {tile(cur.film, cur.shot, 0.35)}
                <span className="ml-1 text-[12px] font-bold">{cur.film.title.slice(0, 26)}</span>
                <span className="ml-auto flex gap-1">
                  <button onClick={() => move(sel!, -1)} className={tb(false)} title="Earlier"><ArrowUp size={13} /></button>
                  <button onClick={() => move(sel!, 1)} className={tb(false)} title="Later"><ArrowDown size={13} /></button>
                  <button onClick={() => remove(sel!)} className={tb(false)} title="Remove"><Trash2 size={13} /></button>
                </span>
              </div>
              <input value={cur.caption} onChange={(e) => patch({ caption: e.target.value })} maxLength={80} placeholder="caption (short, dumb)"
                className="mt-2 w-full rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[14px] font-bold outline-none focus:border-ink" />
              <div className="mt-2 flex flex-wrap gap-1">
                {(['top', 'center', 'bottom'] as const).map((p) => <button key={p} onClick={() => patch({ pos: p })} className={`${tb(cur.pos === p)} border border-hairline`}>{p}</button>)}
                {FONTS.map((f) => <button key={f} onClick={() => patch({ font: f })} className={`${tb(cur.font === f)} border border-hairline`} style={{ fontFamily: FONT_CSS[f] }}>{FONT_LABEL[f]}</button>)}
              </div>
              <label className="mt-2 block text-[11px] text-ink-soft">Length {cur.dur.toFixed(1)}s
                <input type="range" min={0.5} max={Math.min(6, cur.shot.dur - cur.off)} step={0.1} value={cur.dur} onChange={(e) => patch({ dur: Number(e.target.value) })} className="w-full" />
              </label>
              <label className="block text-[11px] text-ink-soft">Start +{cur.off.toFixed(1)}s into the shot
                <input type="range" min={0} max={Math.max(0, cur.shot.dur - 0.5)} step={0.1} value={cur.off} onChange={(e) => { const off = Number(e.target.value); patch({ off, dur: Math.min(cur.dur, cur.shot.dur - off) }); }} className="w-full" />
              </label>
              <div className="mt-1 flex flex-wrap gap-1">
                {FXS.map((f) => <button key={f} onClick={() => patch({ fx: cur.fx.includes(f) ? cur.fx.filter((x) => x !== f) : [...cur.fx, f].slice(-2) })} className={`${tb(cur.fx.includes(f))} border border-hairline`}>{f}</button>)}
              </div>
            </>
          ) : (
            <p className="text-[12.5px] text-ink-soft">Pick a cut on the timeline to set its caption, length and effects. Two effects per cut at most — they are seasoning.</p>
          )}
        </div>

        <div className="rounded-xl border border-hairline bg-paper p-3">
          <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={60} placeholder="Title (optional)" className="mb-2 w-full rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[13px] outline-none focus:border-ink" />
          <div className="mx-auto overflow-hidden rounded-lg bg-black" style={{ width: 216, height: 384 }}>
            <canvas ref={canvas} width={W} height={H} className="block h-full w-full" />
          </div>
          {state === 'playing' || state === 'recording' ? (
            <button onClick={() => { stop.current = true; }} className={`${BUTTON.ghost} mt-2 inline-flex w-full items-center justify-center gap-1.5`}><Square size={13} aria-hidden /> Stop · {Math.round(progress * 100)}%</button>
          ) : (
            <div className="mt-2 grid grid-cols-2 gap-2">
              <button onClick={() => void run(false)} disabled={!cuts.length} className={`${BUTTON.ghost} inline-flex items-center justify-center gap-1.5 disabled:opacity-40`}><Play size={13} aria-hidden /> Preview</button>
              <button onClick={() => void run(true)} disabled={!cuts.length} className={`${BUTTON.primary} inline-flex items-center justify-center gap-1.5 disabled:opacity-40`}><Clapperboard size={13} aria-hidden /> Record</button>
            </div>
          )}
          {out && (
            <>
              <video src={out.url} controls playsInline className="mt-2 w-full rounded-lg border border-hairline bg-black" />
              <button onClick={() => void post()} disabled={state === 'posting'} className={`${BUTTON.primary} mt-2 inline-flex w-full items-center justify-center gap-1.5 disabled:opacity-50`}><Upload size={14} aria-hidden /> {state === 'posting' ? 'Posting…' : 'Post it'}</button>
              <a href={out.url} download={`poz-reel.${out.mime.includes('mp4') ? 'mp4' : 'webm'}`} className={`${BUTTON.ghost} mt-2 inline-flex w-full items-center justify-center gap-1.5`}><Download size={14} aria-hidden /> Download</a>
            </>
          )}
          {message && <p role="alert" className="mt-2 text-[12.5px] font-semibold text-accent-deep">{message}</p>}
          <p className="mt-2 text-[11px] text-ink-soft">Recording plays it through once in real time, sound included. Old films, public domain — cut them however you like.</p>
        </div>
      </div>
    </div>
  );
}
