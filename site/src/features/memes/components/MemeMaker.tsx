'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowUpRight, Brush, Circle, Clapperboard, Dices, Download, Eraser, ImagePlus, Minus, Move, Redo2, Square, Sticker, Trash2, Type, Undo2, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { ASSET_PREFIX, cleanStyle, FONTS, PANELS_MAX, STICKERS_MAX, TEXTS_MAX, type MemeSticker, type MemeText } from '@/lib/memes';
import { arrowPath, drawMemeText, drawSticker, FONT_CSS, FONT_LABEL, hitMemeText, hitSticker } from '@/lib/meme-draw';
import { record, storyboard } from './reel';

/**
 * 짤 만들기 — 그림판 + 글자 + 스티커.
 *
 * 병맛은 잘 그려서 나오는 게 아니라 못 그려서 나온다. 그래서 MS 그림판 느낌으로 간다:
 * 붓·지우개·네모·동그라미·선·화살표, 글자는 여러 개를 아무 데나 끌어 놓고 돌린다, 그림도 스티커로 여러 장 얹는다
 * (흰 바탕에 우는 아기 ↔ 고양이 비교표 같은 것). 되돌리기 있음.
 * 합성은 전부 이 브라우저의 캔버스가 한다 — 서버는 결과 PNG 와 정의만 받는다(서버비 0).
 * 글자·스티커를 찍는 코드는 lib/meme-draw 에 있고 순찰(주민)도 같은 걸 쓴다.
 *
 * 층 순서: 바탕 컷 → 스티커 → 붓질 → 글자. 붓질은 오프스크린 캔버스, 나머지는 값.
 * 리믹스는 원본의 정의(컷·스티커·글자)로 다시 시작한다 — 붓질층은 저장하지 않으므로 이어받지 못한다.
 */
type Tool = 'brush' | 'eraser' | 'rect' | 'circle' | 'line' | 'arrow' | 'text' | 'move';
type Sel = { kind: 'text' | 'sticker'; i: number } | null;
type Snap = { paint: ImageData | null; texts: MemeText[]; stickers: MemeSticker[] };
const PALETTE = ['#ffffff', '#000000', '#ff2d55', '#ffcc00', '#34c759', '#007aff', '#af52de', '#ff9500'];
const W = 900; // 작업 캔버스 폭 — 결과 PNG 크기. 높이는 그림 비율을 따른다
const NEW_TEXT = (t: string, x: number, y: number): MemeText => ({ t, x, y, size: 0.09, color: '#ffffff', stroke: '#000000', rot: 0, font: 'impact', bg: 'none' });
// 바깥 출처(Met 등)는 우리 프록시로 — 브라우저의 cross-origin 이미지 요청을 막는 곳이 있다. 우리 보관함은 그대로
const srcOf = (u: string) => (u.startsWith(ASSET_PREFIX) ? u : `/api/memes/img?u=${encodeURIComponent(u)}`);

export function MemeMaker({ initial, pics, signedIn, autoRoll }: {
  initial?: { image: string; style: { texts: MemeText[]; panels?: (string | null)[]; stickers?: MemeSticker[] }; remixOf: number | null };
  pics: string[];
  signedIn: boolean;
  autoRoll?: boolean;
}) {
  const router = useRouter();
  const view = useRef<HTMLCanvasElement>(null);      // 보이는 캔버스
  const paint = useRef<HTMLCanvasElement | null>(null); // 붓질 층
  const imgs = useRef<(HTMLImageElement | null)[]>([]);
  const stImgs = useRef<Map<string, HTMLImageElement>>(new Map());
  const [size, setSize] = useState({ w: W, h: Math.round(W * 0.75) });
  // 세로로 쌓이는 컷들. 한 장이면 그냥 짤, 네 장이면 "no → no → NO!!!"
  const [panels, setPanels] = useState<(string | null)[]>(
    initial?.style.panels?.length ? initial.style.panels : [initial?.image ?? pics[0] ?? null],
  );
  const base = panels[0] ?? null;
  const [cut, setCut] = useState(0); // 지금 그림을 바꿀 컷
  const [texts, setTexts] = useState<MemeText[]>(initial?.style.texts ?? []);
  const [stickers, setStickers] = useState<MemeSticker[]>(initial?.style.stickers ?? []);
  const [sel, setSel] = useState<Sel>(null);
  const [tool, setTool] = useState<Tool>('text');
  const [pick, setPick] = useState<'bg' | 'sticker'>('bg'); // 아래 그림 띠를 누르면 — 바탕으로 쓸지, 스티커로 얹을지
  const [color, setColor] = useState('#ff2d55');
  const [width, setWidth] = useState(14);
  const [busy, setBusy] = useState<'idle' | 'posting' | 'rolling' | 'reeling'>('idle');
  const [message, setMessage] = useState('');
  const [lines, setLines] = useState<string[]>([]);
  const [shots, setShots] = useState<string[]>(pics);
  const [, bump] = useState(0); // 스티커 그림이 늦게 오면 다시 그리기
  const history = useRef<Snap[]>([]);
  const future = useRef<Snap[]>([]);
  const drag = useRef<{ kind: 'draw' | 'text' | 'sticker' | 'resize'; idx?: number; x0: number; y0: number; snap?: ImageData; sx?: number; sy?: number } | null>(null);

  /** 캔버스 좌표(0~1) — 화면 크기와 무관하게 같은 자리 */
  const at = (e: React.PointerEvent) => {
    const r = view.current!.getBoundingClientRect();
    return { x: (e.clientX - r.left) / r.width, y: (e.clientY - r.top) / r.height };
  };

  const grab = (): Snap => {
    const p = paint.current;
    return { paint: p ? p.getContext('2d')!.getImageData(0, 0, p.width, p.height) : null, texts: texts.map((t) => ({ ...t })), stickers: stickers.map((s) => ({ ...s })) };
  };
  const snapshot = () => { history.current = [...history.current.slice(-24), grab()]; future.current = []; };
  const restore = (s: Snap) => {
    if (paint.current && s.paint) paint.current.getContext('2d')!.putImageData(s.paint, 0, 0);
    setTexts(s.texts); setStickers(s.stickers); setSel(null);
  };
  const undo = () => { const s = history.current.pop(); if (!s) return; future.current.push(grab()); restore(s); };
  const redo = () => { const s = future.current.pop(); if (!s) return; history.current.push(grab()); restore(s); };
  const removeSel = () => {
    if (!sel) return;
    snapshot();
    if (sel.kind === 'text') setTexts(texts.filter((_, i) => i !== sel.i)); else setStickers(stickers.filter((_, i) => i !== sel.i));
    setSel(null);
  };

  // 컷 그림들 로드 — 컷 높이를 합쳐 캔버스 크기를 잡고, 크기가 바뀌면 붓질 층을 새로 만든다
  useEffect(() => {
    let alive = true;
    Promise.all(panels.map((u) => new Promise<HTMLImageElement | null>((ok) => {
      if (!u) return ok(null);
      const im = new Image();
      im.crossOrigin = 'anonymous';         // CORS 로 받아야 toBlob 이 막히지 않는다
      im.onload = () => ok(im);
      im.onerror = () => { setMessage('That picture would not load.'); ok(null); };
      im.src = srcOf(u);
    }))).then((loaded) => {
      if (!alive) return;
      imgs.current = loaded;
      const h = loaded.reduce((sum, im) => sum + Math.round(im ? W * im.height / im.width : W * 0.75), 0);
      const old = paint.current;
      if (!old || old.width !== W || old.height !== h) {
        const c = document.createElement('canvas'); c.width = W; c.height = h;
        if (old) c.getContext('2d')!.drawImage(old, 0, 0); // 붓질은 살려 둔다(컷을 더해도 위 그림은 그대로)
        paint.current = c;
      }
      setSize({ w: W, h });
    });
    return () => { alive = false; };
  }, [panels]);

  // 스티커 그림 — 처음 보는 주소만 받는다
  useEffect(() => {
    for (const s of stickers) {
      if (stImgs.current.has(s.url)) continue;
      const im = new Image(); im.crossOrigin = 'anonymous';
      im.onload = () => { stImgs.current.set(s.url, im); bump((n) => n + 1); };
      im.onerror = () => setMessage('That sticker would not load.');
      im.src = srcOf(s.url);
    }
  }, [stickers]);

  /** 한 장 그리기 — 바탕 → 스티커 → 붓질 → 글자 */
  const draw = useCallback(() => {
    const c = view.current; if (!c) return;
    const ctx = c.getContext('2d')!;
    ctx.clearRect(0, 0, c.width, c.height);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, c.width, c.height);
    let top = 0;
    imgs.current.forEach((im, i) => {
      const h = Math.round(im ? c.width * im.height / im.width : c.width * 0.75);
      if (im) ctx.drawImage(im, 0, top, c.width, h);
      if (imgs.current.length > 1) { ctx.fillStyle = '#111'; ctx.fillRect(0, top + h - 2, c.width, 2); } // 컷 사이 선
      if (i === cut && imgs.current.length > 1) { ctx.strokeStyle = '#ff2d55'; ctx.lineWidth = 3; ctx.setLineDash([8, 6]); ctx.strokeRect(2, top + 2, c.width - 4, h - 4); ctx.setLineDash([]); }
      top += h;
    });
    stickers.forEach((s, i) => { const im = stImgs.current.get(s.url); if (im) drawSticker(ctx, s, im, c.width, c.height, sel?.kind === 'sticker' && sel.i === i); });
    if (paint.current) ctx.drawImage(paint.current, 0, 0);
    texts.forEach((t, i) => drawMemeText(ctx, t, c.width, c.height, sel?.kind === 'text' && sel.i === i));
  }, [texts, stickers, sel, cut]);

  useEffect(() => {
    // 글꼴이 늦게 오면 첫 장이 기본 글꼴로 찍힌다 — 로드 뒤 한 번 더
    draw();
    document.fonts?.ready.then(draw).catch(() => null);
  });

  // Delete·Backspace 로 고른 것 지우기, Ctrl+Z / Ctrl+Shift+Z 되돌리기, Ctrl+V 로 그림 붙여넣기 — 글자 입력 중엔 브라우저 몫
  useEffect(() => {
    const typing = () => { const el = document.activeElement; return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement; };
    const onKey = (e: KeyboardEvent) => {
      if (typing()) return;
      if ((e.key === 'Delete' || e.key === 'Backspace') && sel) { e.preventDefault(); removeSel(); }
      else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); if (e.shiftKey) redo(); else undo(); }
      else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') { e.preventDefault(); redo(); }
    };
    const onPaste = (e: ClipboardEvent) => {
      if (typing()) return;
      const f = [...(e.clipboardData?.files ?? [])].find((x) => x.type.startsWith('image/'));
      if (f) { e.preventDefault(); void pickFile(f, 'sticker'); }
    };
    window.addEventListener('keydown', onKey); window.addEventListener('paste', onPaste);
    return () => { window.removeEventListener('keydown', onKey); window.removeEventListener('paste', onPaste); };
  });

  /** 눌린 자리에 무엇이 있나 — 글자가 스티커보다 위, 나중 것이 먼저 */
  const hit = (x: number, y: number): { sel: Sel; part?: 'handle' | 'body' } => {
    const c = view.current!; const ctx = c.getContext('2d')!;
    for (let i = texts.length - 1; i >= 0; i--) if (hitMemeText(ctx, texts[i], c.width, c.height, x, y)) return { sel: { kind: 'text', i } };
    for (let i = stickers.length - 1; i >= 0; i--) {
      const im = stImgs.current.get(stickers[i].url); if (!im) continue;
      const part = hitSticker(stickers[i], im, c.width, c.height, x, y);
      if (part) return { sel: { kind: 'sticker', i }, part };
    }
    return { sel: null };
  };

  const onDown = (e: React.PointerEvent) => {
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    const { x, y } = at(e);
    if (tool === 'text' || tool === 'move') {
      const h = hit(x, y);
      if (h.sel) {
        snapshot(); setSel(h.sel);
        const o = h.sel.kind === 'text' ? texts[h.sel.i] : stickers[h.sel.i];
        drag.current = { kind: h.part === 'handle' ? 'resize' : h.sel.kind, idx: h.sel.i, x0: x, y0: y, sx: o.x, sy: o.y };
        return;
      }
      if (tool === 'text') {
        if (texts.length >= TEXTS_MAX) { setMessage(`${TEXTS_MAX} lines is plenty.`); return; }
        snapshot();
        setTexts([...texts, NEW_TEXT('TEXT', x, y)]); setSel({ kind: 'text', i: texts.length });
      } else setSel(null);
      return;
    }
    // 붓·지우개·도형
    snapshot();
    const p = paint.current!; const ctx = p.getContext('2d')!;
    drag.current = { kind: 'draw', x0: x, y0: y, snap: ctx.getImageData(0, 0, p.width, p.height) };
    if (tool === 'brush' || tool === 'eraser') {
      ctx.globalCompositeOperation = tool === 'eraser' ? 'destination-out' : 'source-over';
      ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.lineWidth = width; ctx.strokeStyle = color;
      ctx.beginPath(); ctx.moveTo(x * p.width, y * p.height); ctx.lineTo(x * p.width + 0.1, y * p.height);
      ctx.stroke();
      draw();
    }
  };
  const onMove = (e: React.PointerEvent) => {
    const d = drag.current; if (!d) return;
    const { x, y } = at(e);
    const nx = Math.min(1, Math.max(0, d.sx! + x - d.x0)), ny = Math.min(1, Math.max(0, d.sy! + y - d.y0));
    if (d.kind === 'text') { setTexts((ts) => ts.map((t, i) => (i === d.idx ? { ...t, x: nx, y: ny } : t))); return; }
    if (d.kind === 'sticker') { setStickers((ss) => ss.map((s, i) => (i === d.idx ? { ...s, x: nx, y: ny } : s))); return; }
    if (d.kind === 'resize') {
      // 오른쪽 아래 손잡이 — 중심에서 포인터까지가 반폭이다(회전을 되돌려 잰다)
      setStickers((ss) => ss.map((s, i) => {
        if (i !== d.idx) return s;
        const dx = (x - s.x) * size.w, dy = (y - s.y) * size.h; const a = (-s.rot * Math.PI) / 180;
        const rx = dx * Math.cos(a) - dy * Math.sin(a);
        return { ...s, w: Math.min(1, Math.max(0.05, (2 * rx) / size.w)) };
      }));
      return;
    }
    const p = paint.current!; const ctx = p.getContext('2d')!;
    if (tool === 'brush' || tool === 'eraser') {
      ctx.lineTo(x * p.width, y * p.height); ctx.stroke();
    } else {
      // 도형은 시작점에서 지금까지 — 매번 시작 상태로 되돌리고 다시 그린다
      ctx.putImageData(d.snap!, 0, 0);
      ctx.globalCompositeOperation = 'source-over';
      ctx.lineWidth = width; ctx.strokeStyle = color; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      const x0 = d.x0 * p.width, y0 = d.y0 * p.height, x1 = x * p.width, y1 = y * p.height;
      ctx.beginPath();
      if (tool === 'rect') ctx.rect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0));
      else if (tool === 'circle') ctx.ellipse((x0 + x1) / 2, (y0 + y1) / 2, Math.abs(x1 - x0) / 2, Math.abs(y1 - y0) / 2, 0, 0, Math.PI * 2);
      else if (tool === 'arrow') arrowPath(ctx, x0, y0, x1, y1, width);
      else { ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); }
      ctx.stroke();
    }
    draw();
  };
  const onUp = () => { drag.current = null; };

  const patch = (p: Partial<MemeText>) => {
    if (sel?.kind !== 'text') return;
    setTexts((ts) => ts.map((t, i) => (i === sel.i ? { ...t, ...p } : t)));
  };
  const patchSt = (p: Partial<MemeSticker>) => {
    if (sel?.kind !== 'sticker') return;
    setStickers((ss) => ss.map((s, i) => (i === sel.i ? { ...s, ...p } : s)));
  };
  const addSticker = (url: string) => {
    if (stickers.length >= STICKERS_MAX) { setMessage(`${STICKERS_MAX} stickers is plenty.`); return; }
    snapshot();
    setStickers([...stickers, { url, x: 0.5, y: 0.5, w: 0.35, rot: 0 }]); setSel({ kind: 'sticker', i: stickers.length }); setTool('move');
  };
  /** 아래 띠의 그림을 눌렀다 — 모드대로 바탕이 되거나 스티커로 얹힌다 */
  const usePic = (u: string) => { if (pick === 'sticker') addSticker(u); else setPanels((ps) => ps.map((p, i) => (i === cut ? u : p))); };

  /** 🎲 맥락 없는 짤 — 아무 그림 + 아무 문장. 누를 때마다 다시 돌아간다 */
  const roll = useCallback(async () => {
    setBusy('rolling'); setMessage('');
    try {
      const d = await (await fetch('/api/memes/random?n=3', { cache: 'no-store' })).json() as { pics: string[]; lines: string[] };
      setShots(d.pics); setLines(d.lines);
      if (d.pics[0]) setPanels((ps) => [d.pics[0], ...ps.slice(1)]);
      const two = d.lines.slice(0, 2);
      setTexts(two.map((t, i) => ({ ...NEW_TEXT(t, 0.5, i === 0 ? 0.12 : 0.88), size: 0.08, rot: Math.random() * 10 - 5 })));
      setSel(null);
    } catch { setMessage('The dice fell off the table. Try again.'); }
    setBusy('idle');
  }, []);
  useEffect(() => { if (autoRoll) void roll(); }, [autoRoll, roll]);

  /** ▶ 릴 — 스토리보드(컷·글자·스티커·붓질)를 세로 영상으로 녹화한다. 실시간이라 길이만큼 걸린다 */
  const [reel, setReel] = useState<{ url: string; video: Blob; poster: Blob; mime: string } | null>(null);
  const [progress, setProgress] = useState(0);
  const makeReel = async () => {
    setSel(null); setBusy('reeling'); setMessage(''); setReel(null);
    try {
      const heights = imgs.current.map((im) => Math.round(im ? W * im.height / im.width : W * 0.75));
      const scenes = storyboard(imgs.current, heights, size.h, texts, stickers);
      if (!scenes.length) throw new Error('Nothing to record.');
      const out = await record(scenes, W, paint.current, stImgs.current, setProgress);
      setReel({ ...out, url: URL.createObjectURL(out.video) });
    } catch (e) { setMessage(e instanceof Error ? e.message : 'Could not record.'); }
    setBusy('idle');
  };
  const postReel = async () => {
    if (!reel) return;
    if (!signedIn) { setMessage('Log in to post it. Downloading works without an account.'); return; }
    setBusy('posting'); setMessage('');
    const ext = reel.mime.includes('mp4') ? 'mp4' : 'webm';
    const clip = await upload(new File([reel.video], `reel.${ext}`, { type: reel.mime }), 'clip');
    const png = clip ? await upload(new File([reel.poster], 'poster.png', { type: 'image/png' }), 'meme') : null;
    if (!clip || !png) { setBusy('idle'); return; }
    const res = await fetch('/api/memes', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ clip, png, style: cleanStyle({ texts, panels, stickers }), remix_of: initial?.remixOf ?? null }),
    });
    const d = await res.json() as { ok?: boolean; url?: string; message?: string };
    setBusy('idle');
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not post that.'); return; }
    router.push(d.url!);
  };

  const upload = async (file: File, kind: 'inline' | 'meme' | 'clip'): Promise<string | null> => {
    const body = new FormData(); body.append('image', file); body.append('kind', kind);
    const res = await fetch('/api/upload', { method: 'POST', body });
    const d = await res.json() as { url?: string; error?: string };
    if (!d.url) setMessage(d.error ?? 'Upload failed.');
    return d.url ?? null;
  };

  const pickFile = async (file: File, as: 'bg' | 'sticker' = pick) => {
    if (!signedIn) { setMessage('Log in to use your own picture.'); return; }
    const url = await upload(file, 'inline');
    if (!url) return;
    setShots((s) => [url, ...s]);
    if (as === 'sticker') addSticker(url); else setPanels((ps) => ps.map((p, i) => (i === cut ? url : p)));
  };

  const toBlob = () => new Promise<Blob | null>((ok) => {
    setSel(null);
    requestAnimationFrame(() => { draw(); view.current!.toBlob(ok, 'image/png'); });
  });

  const download = async () => {
    const blob = await toBlob(); if (!blob) return;
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'poz-meme.png'; a.click();
  };

  const post = async () => {
    if (!signedIn) { setMessage('Log in to post it. Downloading works without an account.'); return; }
    setBusy('posting'); setMessage('');
    const blob = await toBlob();
    if (!blob) { setBusy('idle'); return; }
    const png = await upload(new File([blob], 'meme.png', { type: 'image/png' }), 'meme');
    if (!png) { setBusy('idle'); return; }
    const res = await fetch('/api/memes', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ image: base ?? png, png, style: cleanStyle({ texts, panels, stickers }), remix_of: initial?.remixOf ?? null }),
    });
    const d = await res.json() as { ok?: boolean; url?: string; message?: string };
    setBusy('idle');
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not post that.'); return; }
    router.push(d.url!);
  };

  const t = sel?.kind === 'text' ? texts[sel.i] : null;
  const st = sel?.kind === 'sticker' ? stickers[sel.i] : null;
  const tb = (on: boolean) => `inline-flex cursor-pointer items-center gap-1 rounded-md px-2 py-1.5 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'text-ink-mid hover:bg-surface'}`;

  return (
    <div className="mt-5 grid gap-4 lg:grid-cols-[minmax(0,1fr)_16rem]">
      <div className="min-w-0">
        {/* ── 도구 ── */}
        <div className="flex flex-wrap items-center gap-1 rounded-xl border border-hairline bg-paper px-2 py-1.5">
          <button onClick={() => setTool('text')} className={tb(tool === 'text')} title="Text — click to add, drag to move"><Type size={14} /> Text</button>
          <button onClick={() => setTool('move')} className={tb(tool === 'move')} title="Move / resize"><Move size={14} /></button>
          <span className="mx-1 h-5 w-px bg-hairline" />
          <button onClick={() => setTool('brush')} className={tb(tool === 'brush')} title="Brush"><Brush size={14} /></button>
          <button onClick={() => setTool('eraser')} className={tb(tool === 'eraser')} title="Eraser"><Eraser size={14} /></button>
          <button onClick={() => setTool('rect')} className={tb(tool === 'rect')} title="Rectangle"><Square size={14} /></button>
          <button onClick={() => setTool('circle')} className={tb(tool === 'circle')} title="Circle"><Circle size={14} /></button>
          <button onClick={() => setTool('line')} className={tb(tool === 'line')} title="Line"><Minus size={14} /></button>
          <button onClick={() => setTool('arrow')} className={tb(tool === 'arrow')} title="Arrow"><ArrowUpRight size={14} /></button>
          <span className="mx-1 h-5 w-px bg-hairline" />
          {PALETTE.map((c) => (
            <button key={c} onClick={() => { setColor(c); if (t) patch({ color: c }); }} aria-label={c}
              className={`size-5 cursor-pointer rounded-full border-2 ${color === c ? 'border-ink' : 'border-hairline'}`} style={{ background: c }} />
          ))}
          <input type="color" value={color} onChange={(e) => { setColor(e.target.value); if (t) patch({ color: e.target.value }); }}
            className="size-5 cursor-pointer rounded border border-hairline bg-transparent p-0" aria-label="Any colour" />
          <input type="range" min={2} max={60} value={width} onChange={(e) => setWidth(Number(e.target.value))} className="w-20" aria-label="Brush size" />
          <span className="mx-1 h-5 w-px bg-hairline" />
          <button onClick={undo} className={tb(false)} title="Undo (Ctrl+Z)"><Undo2 size={14} /></button>
          <button onClick={redo} className={tb(false)} title="Redo (Ctrl+Shift+Z)"><Redo2 size={14} /></button>
        </div>

        {/* ── 캔버스 — 무대 높이는 고정, 그림은 그 안에 맞춰 넣는다(flex 여야 max-h 가 무대 기준으로 풀린다) ── */}
        <div className="mt-3 flex h-[min(70vh,640px)] items-center justify-center overflow-hidden rounded-xl border border-hairline bg-[#e9e6e8]">
          <canvas
            ref={view} width={size.w} height={size.h}
            onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
            className={`block max-h-full max-w-full touch-none ${tool === 'text' || tool === 'move' ? 'cursor-move' : 'cursor-crosshair'}`}
            style={{ aspectRatio: `${size.w} / ${size.h}` }}
          />
        </div>

        {/* ── 그림 ── */}
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <button onClick={() => void roll()} disabled={busy === 'rolling'} className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
            <Dices size={15} aria-hidden /> No context
          </button>
          <label className={`${BUTTON.ghost} inline-flex cursor-pointer items-center gap-1.5`}>
            <ImagePlus size={14} aria-hidden /> My picture
            <input type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void pickFile(f); }} />
          </label>
          <button onClick={() => setPanels((ps) => ps.map((p, i) => (i === cut ? null : p)))} className={BUTTON.ghost} title="White background">Blank</button>
          <span className="mx-1 h-5 w-px bg-hairline" />
          {/* 띠의 그림을 어디에 쓸지 — 바탕인지 스티커인지 */}
          <span className="inline-flex rounded-md border border-hairline p-0.5">
            <button onClick={() => setPick('bg')} className={tb(pick === 'bg')} title="Clicking a picture below sets the background">Background</button>
            <button onClick={() => setPick('sticker')} className={tb(pick === 'sticker')} title="Clicking a picture below drops it on top as a sticker (paste works too)"><Sticker size={13} /> Sticker</button>
          </span>
          <span className="mx-1 h-5 w-px bg-hairline" />
          <button onClick={() => { if (panels.length < PANELS_MAX) { setPanels([...panels, panels[cut]]); setCut(panels.length); } }} disabled={panels.length >= PANELS_MAX} className={`${BUTTON.ghost} disabled:opacity-40`} title="Stack another panel below">+ Panel</button>
          {panels.length > 1 && (
            <>
              {panels.map((_, i) => (
                <button key={i} onClick={() => setCut(i)} className={`size-7 cursor-pointer rounded-full text-[12px] font-bold ${cut === i ? 'bg-ink text-paper' : 'border border-hairline text-ink-mid'}`}>{i + 1}</button>
              ))}
              <button onClick={() => { setPanels(panels.filter((_, i) => i !== cut)); setCut(Math.max(0, cut - 1)); }} className={BUTTON.ghost} title="Remove this panel">− Panel</button>
            </>
          )}
        </div>
        <div className="mt-2 flex gap-1.5 overflow-x-auto">
          {shots.map((u) => (
            <button key={u} onClick={() => usePic(u)} title={pick === 'sticker' ? 'Add as sticker' : 'Use as background'}
              className={`shrink-0 overflow-hidden rounded border-2 ${panels[cut] === u ? 'border-ink' : 'border-hairline'}`}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={u} alt="" className="h-12 w-16 object-cover" />
            </button>
          ))}
        </div>
        {lines.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-1.5">
            {lines.map((l) => (
              <button key={l} onClick={() => { if (t) patch({ t: l }); else { snapshot(); setTexts([...texts, NEW_TEXT(l, 0.5, 0.5)]); setSel({ kind: 'text', i: texts.length }); } }}
                className="cursor-pointer rounded-full border border-hairline bg-paper px-2.5 py-1 text-[12px] hover:bg-surface">
                {l}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* ── 고른 것의 설정 + 올리기 ── */}
      <div className="flex flex-col gap-3">
        <div className="rounded-xl border border-hairline bg-paper p-3">
          {t ? (
            <>
              <textarea value={t.t} onChange={(e) => patch({ t: e.target.value })} rows={2} maxLength={120}
                className="w-full rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[14px] font-bold outline-none focus:border-ink" />
              <div className="mt-2 grid grid-cols-2 gap-1.5">
                {FONTS.map((f) => (
                  <button key={f} onClick={() => patch({ font: f })} className={`${tb(t.font === f)} justify-center border border-hairline`} style={{ fontFamily: FONT_CSS[f] }}>
                    {FONT_LABEL[f]}
                  </button>
                ))}
              </div>
              <div className="mt-2 flex flex-wrap gap-1">
                {(['none', 'box', 'bubble', 'badge'] as const).map((b) => (
                  <button key={b} onClick={() => patch({ bg: b })} className={`${tb(t.bg === b)} border border-hairline`}>
                    {{ none: 'Plain', box: 'Box', bubble: 'Speech', badge: 'Badge' }[b]}
                  </button>
                ))}
              </div>
              <label className="mt-2 block text-[11px] text-ink-soft">Size
                <input type="range" min={0.03} max={0.3} step={0.005} value={t.size} onChange={(e) => patch({ size: Number(e.target.value) })} className="w-full" />
              </label>
              <label className="block text-[11px] text-ink-soft">Rotate
                <input type="range" min={-45} max={45} value={t.rot} onChange={(e) => patch({ rot: Number(e.target.value) })} className="w-full" />
              </label>
              <div className="mt-1 flex items-center gap-2 text-[11px] text-ink-soft">
                <label className="inline-flex items-center gap-1">Fill <input type="color" value={t.color} onChange={(e) => patch({ color: e.target.value })} className="size-5 rounded border border-hairline p-0" /></label>
                <label className="inline-flex items-center gap-1">Outline <input type="color" value={t.stroke} onChange={(e) => patch({ stroke: e.target.value })} className="size-5 rounded border border-hairline p-0" /></label>
                <button onClick={removeSel} className="ml-auto cursor-pointer text-ink-soft hover:text-accent-deep" aria-label="Delete text" title="Delete (Del)"><Trash2 size={14} /></button>
              </div>
            </>
          ) : st ? (
            <>
              <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Sticker</p>
              <label className="mt-2 block text-[11px] text-ink-soft">Size
                <input type="range" min={0.05} max={1} step={0.01} value={st.w} onChange={(e) => patchSt({ w: Number(e.target.value) })} className="w-full" />
              </label>
              <label className="block text-[11px] text-ink-soft">Rotate
                <input type="range" min={-180} max={180} value={st.rot} onChange={(e) => patchSt({ rot: Number(e.target.value) })} className="w-full" />
              </label>
              <div className="mt-1 flex items-center gap-2 text-[11px]">
                <button onClick={() => { if (sel?.kind !== 'sticker' || sel.i === 0) return; snapshot(); const ss = [...stickers]; const [s] = ss.splice(sel.i, 1); ss.unshift(s); setStickers(ss); setSel({ kind: 'sticker', i: 0 }); }} className={`${tb(false)} border border-hairline`}>Send back</button>
                <button onClick={() => { if (sel?.kind !== 'sticker' || sel.i === stickers.length - 1) return; snapshot(); const ss = [...stickers]; const [s] = ss.splice(sel.i, 1); ss.push(s); setStickers(ss); setSel({ kind: 'sticker', i: ss.length - 1 }); }} className={`${tb(false)} border border-hairline`}>Bring front</button>
                <button onClick={removeSel} className="ml-auto cursor-pointer text-ink-soft hover:text-accent-deep" aria-label="Delete sticker" title="Delete (Del)"><Trash2 size={14} /></button>
              </div>
              <p className="mt-2 text-[11.5px] text-ink-soft">Drag to move. Drag the pink corner to resize.</p>
            </>
          ) : (
            <p className="text-[12.5px] text-ink-soft">
              <b>Text</b>: click anywhere to drop words, drag to move, <b>Del</b> removes. <b>Sticker</b>: switch the row below to Sticker and click a picture, or paste one (Ctrl+V).
              <b> Blank</b> gives you a white sheet for charts and arrows. <b>Brush</b>: draw badly on purpose.
            </p>
          )}
        </div>

        <div className="rounded-xl border border-hairline bg-paper p-3">
          <button onClick={() => void post()} disabled={busy === 'posting'} className={`${BUTTON.primary} inline-flex w-full items-center justify-center gap-1.5 disabled:opacity-50`}>
            <Upload size={14} aria-hidden /> {busy === 'posting' ? 'Posting…' : initial?.remixOf ? 'Post remix' : 'Post it'}
          </button>
          <button onClick={() => void download()} className={`${BUTTON.ghost} mt-2 inline-flex w-full items-center justify-center gap-1.5`}>
            <Download size={14} aria-hidden /> Download PNG
          </button>
          {message && <p role="alert" className="mt-2 text-[12.5px] font-semibold text-accent-deep">{message}</p>}
          {!signedIn && <p className="mt-2 text-[11.5px] text-ink-soft">Anyone can make and download. Posting to the wall needs an account.</p>}
        </div>

        {/* ── 릴 — 컷이 장면, 글자가 대사. 세로 영상으로 녹화한다 ── */}
        <div className="rounded-xl border border-hairline bg-paper p-3">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Make it move</p>
          <p className="mt-1 text-[11.5px] text-ink-soft">Each panel is a scene, each line comes in on its own. Vertical, like a short. Recording takes as long as the clip.</p>
          <button onClick={() => void makeReel()} disabled={busy !== 'idle'} className={`${BUTTON.ghost} mt-2 inline-flex w-full items-center justify-center gap-1.5 disabled:opacity-50`}>
            <Clapperboard size={14} aria-hidden /> {busy === 'reeling' ? `Recording… ${Math.round(progress * 100)}%` : reel ? 'Record again' : 'Record a reel'}
          </button>
          {reel && (
            <>
              <video src={reel.url} controls autoPlay muted loop playsInline className="mt-2 w-full rounded-lg border border-hairline bg-black" />
              <button onClick={() => void postReel()} disabled={busy === 'posting'} className={`${BUTTON.primary} mt-2 inline-flex w-full items-center justify-center gap-1.5 disabled:opacity-50`}>
                <Upload size={14} aria-hidden /> {busy === 'posting' ? 'Posting…' : 'Post the reel'}
              </button>
              <a href={reel.url} download={`poz-reel.${reel.mime.includes('mp4') ? 'mp4' : 'webm'}`} className={`${BUTTON.ghost} mt-2 inline-flex w-full items-center justify-center gap-1.5`}>
                <Download size={14} aria-hidden /> Download
              </a>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
