'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Brush, Circle, Dices, Download, Eraser, ImagePlus, Minus, Move, Redo2, Square, Trash2, Type, Undo2, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { cleanStyle, FONTS, PANELS_MAX, TEXTS_MAX, type MemeText } from '@/lib/memes';
import { drawMemeText, FONT_CSS, FONT_LABEL, hitMemeText } from '@/lib/meme-draw';

/**
 * 짤 만들기 — 그림판 + 글자.
 *
 * 병맛은 잘 그려서 나오는 게 아니라 못 그려서 나온다. 그래서 MS 그림판 느낌으로 간다:
 * 붓·지우개·네모·동그라미·선, 글자는 여러 개를 아무 데나 끌어 놓고 돌린다. 되돌리기 있음.
 * 합성은 전부 이 브라우저의 캔버스가 한다 — 서버는 결과 PNG 와 정의만 받는다(서버비 0).
 * 글자를 찍는 코드는 lib/meme-draw 에 있고 순찰(주민)도 같은 걸 쓴다.
 *
 * 그림층(붓질)은 오프스크린 캔버스에 쌓고, 글자는 값으로 들고 있다가 그릴 때 얹는다.
 * 리믹스는 결과 PNG 를 바탕으로 다시 시작한다 — 남의 붓질 위에 내 붓질이 올라간다.
 */
type Tool = 'brush' | 'eraser' | 'rect' | 'circle' | 'line' | 'text' | 'move';
const PALETTE = ['#ffffff', '#000000', '#ff2d55', '#ffcc00', '#34c759', '#007aff', '#af52de', '#ff9500'];
const W = 900; // 작업 캔버스 폭 — 결과 PNG 크기. 높이는 그림 비율을 따른다
const NEW_TEXT = (t: string, x: number, y: number): MemeText => ({ t, x, y, size: 0.09, color: '#ffffff', stroke: '#000000', rot: 0, font: 'impact', bg: 'none' });

export function MemeMaker({ initial, pics, signedIn, autoRoll }: {
  initial?: { image: string; style: { texts: MemeText[]; panels?: (string | null)[] }; remixOf: number | null };
  pics: string[];
  signedIn: boolean;
  autoRoll?: boolean;
}) {
  const router = useRouter();
  const view = useRef<HTMLCanvasElement>(null);      // 보이는 캔버스
  const paint = useRef<HTMLCanvasElement | null>(null); // 붓질 층
  const imgs = useRef<(HTMLImageElement | null)[]>([]);
  const [size, setSize] = useState({ w: W, h: Math.round(W * 0.75) });
  // 세로로 쌓이는 컷들. 한 장이면 그냥 짤, 네 장이면 "no → no → NO!!!"
  const [panels, setPanels] = useState<(string | null)[]>(
    initial?.style.panels?.length ? initial.style.panels : [initial?.image ?? pics[0] ?? null],
  );
  const base = panels[0] ?? null;
  const [cut, setCut] = useState(0); // 지금 그림을 바꿀 컷
  const [texts, setTexts] = useState<MemeText[]>(initial?.style.texts ?? []);
  const [sel, setSel] = useState<number | null>(null);
  const [tool, setTool] = useState<Tool>('text');
  const [color, setColor] = useState('#ff2d55');
  const [width, setWidth] = useState(14);
  const [busy, setBusy] = useState<'idle' | 'posting' | 'rolling'>('idle');
  const [message, setMessage] = useState('');
  const [lines, setLines] = useState<string[]>([]);
  const [shots, setShots] = useState<string[]>(pics);
  const history = useRef<{ paint: ImageData | null; texts: MemeText[] }[]>([]);
  const future = useRef<{ paint: ImageData | null; texts: MemeText[] }[]>([]);
  const drag = useRef<{ kind: 'draw' | 'text'; idx?: number; x0: number; y0: number; snap?: ImageData; sx?: number; sy?: number } | null>(null);

  /** 캔버스 좌표(0~1) — 화면 크기와 무관하게 같은 자리 */
  const at = (e: React.PointerEvent) => {
    const r = view.current!.getBoundingClientRect();
    return { x: (e.clientX - r.left) / r.width, y: (e.clientY - r.top) / r.height };
  };

  const snapshot = () => {
    const p = paint.current;
    history.current = [...history.current.slice(-24), {
      paint: p ? p.getContext('2d')!.getImageData(0, 0, p.width, p.height) : null,
      texts: texts.map((t) => ({ ...t })),
    }];
    future.current = [];
  };
  const restore = (s: { paint: ImageData | null; texts: MemeText[] }) => {
    if (paint.current && s.paint) paint.current.getContext('2d')!.putImageData(s.paint, 0, 0);
    setTexts(s.texts);
  };
  const undo = () => {
    const s = history.current.pop(); if (!s) return;
    const p = paint.current;
    future.current.push({ paint: p ? p.getContext('2d')!.getImageData(0, 0, p.width, p.height) : null, texts });
    restore(s); setSel(null);
  };
  const redo = () => {
    const s = future.current.pop(); if (!s) return;
    const p = paint.current;
    history.current.push({ paint: p ? p.getContext('2d')!.getImageData(0, 0, p.width, p.height) : null, texts });
    restore(s); setSel(null);
  };
  const removeSel = () => {
    if (sel === null) return;
    snapshot(); setTexts(texts.filter((_, i) => i !== sel)); setSel(null);
  };

  // 컷 그림들 로드 — 컷 높이를 합쳐 캔버스 크기를 잡고, 크기가 바뀌면 붓질 층을 새로 만든다
  useEffect(() => {
    let alive = true;
    Promise.all(panels.map((u) => new Promise<HTMLImageElement | null>((ok) => {
      if (!u) return ok(null);
      const im = new Image();
      im.crossOrigin = 'anonymous';         // 풀의 출처는 전부 CORS 를 열어 둔다 — 이게 없으면 toBlob 이 막힌다
      im.onload = () => ok(im);
      im.onerror = () => { setMessage('That picture would not load.'); ok(null); };
      im.src = u;
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

  /** 한 장 그리기 — 바탕 → 붓질 → 글자 */
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
    if (paint.current) ctx.drawImage(paint.current, 0, 0);
    texts.forEach((t, i) => drawMemeText(ctx, t, c.width, c.height, i === sel));
  }, [texts, sel, cut]);

  useEffect(() => {
    // 글꼴이 늦게 오면 첫 장이 기본 글꼴로 찍힌다 — 로드 뒤 한 번 더
    draw();
    document.fonts?.ready.then(draw).catch(() => null);
  }, [draw, size]);

  // Delete·Backspace 로 고른 글자 지우기, Ctrl+Z / Ctrl+Shift+Z 되돌리기 — 글자 입력 중엔 브라우저 몫
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = document.activeElement;
      if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) return;
      if ((e.key === 'Delete' || e.key === 'Backspace') && sel !== null) { e.preventDefault(); removeSel(); }
      else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); if (e.shiftKey) redo(); else undo(); }
      else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') { e.preventDefault(); redo(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  /** 글자 맞히기 — 눌린 자리에 글자가 있나 (위에 그려진 것부터) */
  const hit = (x: number, y: number) => {
    const c = view.current!; const ctx = c.getContext('2d')!;
    for (let i = texts.length - 1; i >= 0; i--) if (hitMemeText(ctx, texts[i], c.width, c.height, x, y)) return i;
    return -1;
  };

  const onDown = (e: React.PointerEvent) => {
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    const { x, y } = at(e);
    if (tool === 'text' || tool === 'move') {
      const i = hit(x, y);
      if (i >= 0) { snapshot(); setSel(i); drag.current = { kind: 'text', idx: i, x0: x, y0: y, sx: texts[i].x, sy: texts[i].y }; return; }
      if (tool === 'text') {
        if (texts.length >= TEXTS_MAX) { setMessage(`${TEXTS_MAX} lines is plenty.`); return; }
        snapshot();
        setTexts([...texts, NEW_TEXT('TEXT', x, y)]); setSel(texts.length);
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
    if (d.kind === 'text' && d.idx !== undefined) {
      setTexts((ts) => ts.map((t, i) => (i === d.idx ? { ...t, x: Math.min(1, Math.max(0, d.sx! + x - d.x0)), y: Math.min(1, Math.max(0, d.sy! + y - d.y0)) } : t)));
      return;
    }
    const p = paint.current!; const ctx = p.getContext('2d')!;
    if (tool === 'brush' || tool === 'eraser') {
      ctx.lineTo(x * p.width, y * p.height); ctx.stroke();
    } else {
      // 도형은 시작점에서 지금까지 — 매번 시작 상태로 되돌리고 다시 그린다
      ctx.putImageData(d.snap!, 0, 0);
      ctx.globalCompositeOperation = 'source-over';
      ctx.lineWidth = width; ctx.strokeStyle = color; ctx.lineCap = 'round';
      const x0 = d.x0 * p.width, y0 = d.y0 * p.height, x1 = x * p.width, y1 = y * p.height;
      ctx.beginPath();
      if (tool === 'rect') ctx.rect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0));
      else if (tool === 'circle') ctx.ellipse((x0 + x1) / 2, (y0 + y1) / 2, Math.abs(x1 - x0) / 2, Math.abs(y1 - y0) / 2, 0, 0, Math.PI * 2);
      else { ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); }
      ctx.stroke();
    }
    draw();
  };
  const onUp = () => { drag.current = null; };

  const patch = (p: Partial<MemeText>) => {
    if (sel === null) return;
    setTexts((ts) => ts.map((t, i) => (i === sel ? { ...t, ...p } : t)));
  };

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

  const upload = async (file: File, kind: 'inline' | 'meme'): Promise<string | null> => {
    const body = new FormData(); body.append('image', file); body.append('kind', kind);
    const res = await fetch('/api/upload', { method: 'POST', body });
    const d = await res.json() as { url?: string; error?: string };
    if (!d.url) setMessage(d.error ?? 'Upload failed.');
    return d.url ?? null;
  };

  const pickFile = async (file: File) => {
    if (!signedIn) { setMessage('Log in to use your own picture.'); return; }
    const url = await upload(file, 'inline');
    if (url) { setPanels((ps) => ps.map((p, i) => (i === cut ? url : p))); setShots([url, ...shots]); }
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
      body: JSON.stringify({ image: base ?? png, png, style: cleanStyle({ texts, panels }), remix_of: initial?.remixOf ?? null }),
    });
    const d = await res.json() as { ok?: boolean; url?: string; message?: string };
    setBusy('idle');
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not post that.'); return; }
    router.push(d.url!);
  };

  const t = sel !== null ? texts[sel] : null;
  const tb = (on: boolean) => `inline-flex cursor-pointer items-center gap-1 rounded-md px-2 py-1.5 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'text-ink-mid hover:bg-surface'}`;

  return (
    <div className="mt-5 grid gap-4 lg:grid-cols-[minmax(0,1fr)_16rem]">
      <div className="min-w-0">
        {/* ── 도구 ── */}
        <div className="flex flex-wrap items-center gap-1 rounded-xl border border-hairline bg-paper px-2 py-1.5">
          <button onClick={() => setTool('text')} className={tb(tool === 'text')} title="Text — click to add, drag to move"><Type size={14} /> Text</button>
          <button onClick={() => setTool('move')} className={tb(tool === 'move')} title="Move text"><Move size={14} /></button>
          <span className="mx-1 h-5 w-px bg-hairline" />
          <button onClick={() => setTool('brush')} className={tb(tool === 'brush')} title="Brush"><Brush size={14} /></button>
          <button onClick={() => setTool('eraser')} className={tb(tool === 'eraser')} title="Eraser"><Eraser size={14} /></button>
          <button onClick={() => setTool('rect')} className={tb(tool === 'rect')} title="Rectangle"><Square size={14} /></button>
          <button onClick={() => setTool('circle')} className={tb(tool === 'circle')} title="Circle"><Circle size={14} /></button>
          <button onClick={() => setTool('line')} className={tb(tool === 'line')} title="Line"><Minus size={14} /></button>
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

        {/* ── 캔버스 ── */}
        <div className="mt-3 overflow-hidden rounded-xl border border-hairline bg-[#e9e6e8]">
          <canvas
            ref={view} width={size.w} height={size.h}
            onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
            className={`block w-full touch-none ${tool === 'text' || tool === 'move' ? 'cursor-move' : 'cursor-crosshair'}`}
            style={{ aspectRatio: `${size.w} / ${size.h}` }}
          />
        </div>

        {/* ── 바탕 그림 ── */}
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <button onClick={() => void roll()} disabled={busy === 'rolling'} className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
            <Dices size={15} aria-hidden /> No context
          </button>
          <label className={`${BUTTON.ghost} inline-flex cursor-pointer items-center gap-1.5`}>
            <ImagePlus size={14} aria-hidden /> My picture
            <input type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void pickFile(f); }} />
          </label>
          <button onClick={() => setPanels((ps) => ps.map((p, i) => (i === cut ? null : p)))} className={BUTTON.ghost}>Blank</button>
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
          <div className="flex gap-1.5 overflow-x-auto">
            {shots.map((u) => (
              <button key={u} onClick={() => setPanels((ps) => ps.map((p, i) => (i === cut ? u : p)))} className={`shrink-0 overflow-hidden rounded border-2 ${panels[cut] === u ? 'border-ink' : 'border-hairline'}`}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={u} alt="" className="h-12 w-16 object-cover" />
              </button>
            ))}
          </div>
        </div>
        {lines.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-1.5">
            {lines.map((l) => (
              <button key={l} onClick={() => { if (t) patch({ t: l }); else { snapshot(); setTexts([...texts, NEW_TEXT(l, 0.5, 0.5)]); setSel(texts.length); } }}
                className="cursor-pointer rounded-full border border-hairline bg-paper px-2.5 py-1 text-[12px] hover:bg-surface">
                {l}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* ── 글자 설정 + 올리기 ── */}
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
          ) : (
            <p className="text-[12.5px] text-ink-soft">
              <b>Text</b> tool: click anywhere to drop words, drag to move, <b>Del</b> removes. <b>Brush</b>: draw badly on purpose.
              <b> No context</b> rolls a random picture with random lines.
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
      </div>
    </div>
  );
}
