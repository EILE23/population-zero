'use client';
import { useEffect, useRef, useState } from 'react';
import { Fish, ShoppingBag, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { figure } from '@/lib/stickman';
import { figureColor } from '@/lib/tower';
import { drawGlyph } from '@/lib/pond-glyph';
import { BADGE_BY_KEY, BAITS, ITEM_BY_KEY, ITEM_LIST, POND_W, RARITY_COLOR, RARITY_NAME, RODS, residentState, sittingResidents, ZONES, zoneAt, type BaitKey, type Item } from '@/lib/pond';

/**
 * Pond — 화면. 물가 한 줄(4000px)을 걸어 다니다 앉아서 던진다. 규칙·표·뽑기는 lib/pond + /api/pond.
 * 던지기(서버가 뽑아 둠) → 기다림 → 찌가 잠기면 창 안에 챔질 → 카드. 주민은 씨앗대로 앉아 낚고, 사람은 DO 로 자리·채팅.
 */
export interface ResidentLite { id: number; handle: string }
interface Me { id: number; handle: string }
interface State { rod: number; coins: number; casts: number; bait: Partial<Record<BaitKey, number>>; book: Record<string, number>; badges: string[] }
interface Other { uid: number; handle: string; x: number; tx: number; pose: string; status: 'active' | 'rest' }
interface Catch { item: Item; earned: number; newBadges: string[]; at: number }
type Phase = 'walk' | 'cast' | 'wait' | 'bite' | 'reel' | 'card';

const VIEW_W = 960, VIEW_H = 420, BANK = 262;
const TOUCH = typeof window !== 'undefined' && 'ontouchstart' in window;

export function PondGame({ residents, me, initial, memes }: { residents: ResidentLite[]; me: Me | null; initial: State | null; memes: string[] }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const wrap = useRef<HTMLDivElement>(null);
  const ws = useRef<WebSocket | null>(null);
  const x = useRef(120); const face = useRef<1 | -1>(1);
  const input = useRef({ left: false, right: false });
  const phase = useRef<Phase>('walk');
  const timing = useRef({ castAt: 0, wait: 0, window: 0, biteAt: 0 });
  const others = useRef(new Map<number, Other>());
  const cam = useRef(0);
  const [state, setState] = useState<State | null>(initial);
  const [bait, setBait] = useState<BaitKey | null>('worm');
  const [card, setCard] = useState<Catch | null>(null);
  const [message, setMessage] = useState('');
  const [hud, setHud] = useState({ zone: ZONES[0], phase: 'walk' as Phase, online: 0 });
  const [chats, setChats] = useState<{ who: string; body: string }[]>([]);
  const [line, setLine] = useState('');
  const [shop, setShop] = useState(false);
  const [book, setBook] = useState(false);
  const posted = useRef<number | null>(null);
  const [posting, setPosting] = useState(false);
  const spectator = !me;
  const memeImgs = useRef<HTMLImageElement[]>([]);
  useEffect(() => { memeImgs.current = memes.slice(0, 6).map((u) => { const im = new Image(); im.src = u; return im; }); }, [memes]);

  // ── 서버(방) ──
  useEffect(() => {
    let alive = true, sock: WebSocket | null = null, retry = 0;
    const connect = () => {
      if (!alive) return;
      sock = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws/pond`); ws.current = sock;
      sock.onopen = () => { retry = 0; };
      sock.onmessage = (e) => {
        let m: { t: string; [k: string]: unknown }; try { m = JSON.parse(String(e.data)); } catch { return; }
        const map = others.current;
        const put = (u: Record<string, unknown>) => {
          const uid = Number(u.uid);
          if (me && uid === me.id) { if (m.t === 'init') { x.current = Number(u.x) || 120; cam.current = x.current - VIEW_W / 2; } return; }
          const prev = map.get(uid);
          map.set(uid, { uid, handle: String(u.handle ?? ''), x: prev?.x ?? (Number(u.x) || 0), tx: Number(u.x) || 0, pose: String(u.pose ?? 'stand'), status: u.status === 'rest' ? 'rest' : 'active' });
        };
        if (m.t === 'init') { map.clear(); for (const u of m.users as Record<string, unknown>[]) put(u); }
        else if (m.t === 'user') put(m.u as Record<string, unknown>);
        else if (m.t === 'pos') { const o = map.get(Number(m.uid)); if (o) { o.tx = Number(m.x); o.pose = String(m.pose); o.status = 'active'; } }
        else if (m.t === 'rest') { const o = map.get(Number(m.uid)); if (o) { o.status = 'rest'; o.pose = 'sit'; } }
        else if (m.t === 'leave') map.delete(Number(m.uid));
        else if (m.t === 'chat') setChats((c) => [...c.slice(-7), { who: String(m.handle), body: String(m.body) }]);
      };
      sock.onclose = () => { if (alive) setTimeout(connect, Math.min(15000, 1000 * 2 ** retry++)); };
    };
    connect();
    return () => { alive = false; sock?.close(); };
  }, [me]);

  // ── 낚시 동작 ──
  const api = async (body: Record<string, unknown>) => {
    const res = await fetch('/api/pond', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
    const d = await res.json() as Record<string, unknown> & { message?: string };
    if (!res.ok) { setMessage(d.message ?? 'Hm.'); return null; }
    return d;
  };
  const cast = async () => {
    if (spectator || phase.current !== 'walk') return;
    const zone = zoneAt(x.current);
    if ((state?.rod ?? 1) < zone.rod) { setMessage(`${zone.name} needs rod level ${zone.rod}. Yours is ${state?.rod ?? 1}.`); return; }
    phase.current = 'cast'; setMessage(''); setCard(null);
    const d = await api({ action: 'cast', zone: zone.key, bait });
    if (!d) { phase.current = 'walk'; return; }
    setState((s) => (s ? { ...s, bait: d.bait as State['bait'], casts: s.casts + 1 } : s));
    timing.current = { castAt: performance.now(), wait: Number(d.wait), window: Number(d.window), biteAt: 0 };
    phase.current = 'wait';
  };
  const hook = async () => {
    if (spectator) return;
    if (phase.current === 'wait') { // 너무 이르다
      phase.current = 'reel'; const d = await api({ action: 'miss' }); if (d) setState(d as unknown as State);
      setMessage('Too early. Whatever it was, it left.'); phase.current = 'walk'; return;
    }
    if (phase.current !== 'bite') return;
    phase.current = 'reel';
    const d = await api({ action: 'land' });
    if (!d) { phase.current = 'walk'; return; }
    const item = d.item as Item | null;
    setState(d as unknown as State);
    if (item) { setCard({ item, earned: Number(d.earned), newBadges: (d.newBadges as string[]) ?? [], at: Date.now() }); phase.current = 'card'; ws.current?.send(JSON.stringify({ t: 'chat', body: `caught ${item.name}` })); }
    else { setMessage('It got away.'); phase.current = 'walk'; }
  };
  const missed = async () => { phase.current = 'reel'; const d = await api({ action: 'miss' }); if (d) setState(d as unknown as State); setMessage('Too slow. It got away.'); phase.current = 'walk'; };
  const buy = async (what: string) => { const d = await api({ action: 'buy', what }); if (d) { setState(d as unknown as State); setMessage(''); } };

  /** 벽에 올리기 — 카드를 그림으로 찍어 짤로 게시 */
  const postCard = async () => {
    if (!card || !me || posted.current === card.at) return;
    setPosting(true);
    const c = document.createElement('canvas'); c.width = 900; c.height = 900; const ctx = c.getContext('2d')!;
    ctx.fillStyle = '#f4f1f2'; ctx.fillRect(0, 0, 900, 900);
    ctx.fillStyle = '#dfe9ee'; ctx.fillRect(0, 520, 900, 380);
    drawGlyph(ctx, card.item.glyph, 450, 420, 380, card.at);
    ctx.fillStyle = RARITY_COLOR[card.item.rarity]; ctx.font = 'bold 26px ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillText(RARITY_NAME[card.item.rarity].toUpperCase(), 450, 700);
    ctx.fillStyle = '#1b0c15'; ctx.font = 'bold 44px system-ui, sans-serif';
    const words = `${me.handle} caught ${card.item.name}`.split(' '); const lines: string[] = []; let cur = '';
    for (const w of words) { const t = cur ? `${cur} ${w}` : w; if (ctx.measureText(t).width > 800 && cur) { lines.push(cur); cur = w; } else cur = t; } lines.push(cur);
    lines.forEach((l, i) => ctx.fillText(l, 450, 760 + i * 52));
    ctx.fillStyle = '#8f8489'; ctx.font = '22px ui-monospace, monospace'; ctx.fillText('population.town/pond', 450, 870);
    const blob = await new Promise<Blob | null>((ok) => c.toBlob(ok, 'image/png'));
    if (!blob) { setPosting(false); return; }
    const body = new FormData(); body.append('image', new File([blob], 'catch.png', { type: 'image/png' })); body.append('kind', 'meme');
    const up = await (await fetch('/api/upload', { method: 'POST', body })).json() as { url?: string };
    if (up.url) {
      const res = await fetch('/api/memes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ png: up.url, caption: `${me.handle} caught ${card.item.name}` }) });
      if (res.ok) { posted.current = card.at; setMessage('Posted to the wall (and your blog).'); }
    }
    setPosting(false);
  };

  // ── 입력 ──
  useEffect(() => {
    if (spectator) return;
    const typing = () => { const el = document.activeElement; return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement; };
    const kd = (e: KeyboardEvent) => {
      if (typing()) return;
      if (e.key === 'ArrowLeft' || e.key === 'a') { input.current.left = true; e.preventDefault(); }
      else if (e.key === 'ArrowRight' || e.key === 'd') { input.current.right = true; e.preventDefault(); }
      else if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); if (phase.current === 'walk') void cast(); else if (phase.current === 'wait' || phase.current === 'bite') void hook(); else if (phase.current === 'card') { setCard(null); phase.current = 'walk'; } }
    };
    const ku = (e: KeyboardEvent) => { if (e.key === 'ArrowLeft' || e.key === 'a') input.current.left = false; if (e.key === 'ArrowRight' || e.key === 'd') input.current.right = false; };
    window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  });

  // ── 루프 ──
  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    let raf = 0, last = performance.now(), sent = 0, hudAt = 0;
    const hour = () => Math.floor(Date.now() / 3600000);
    let sitting = sittingResidents(hour(), residents.length), sittingHour = hour();
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.1, (now - last) / 1000); last = now; const t = Date.now() / 1000;
      if (hour() !== sittingHour) { sittingHour = hour(); sitting = sittingResidents(sittingHour, residents.length); }
      // 걷기 (앉아 있으면 못 움직인다)
      if (!spectator && phase.current === 'walk') {
        const dir = (input.current.right ? 1 : 0) - (input.current.left ? 1 : 0);
        if (dir) { x.current = Math.max(30, Math.min(POND_W - 30, x.current + dir * 220 * dt)); face.current = dir as 1 | -1; }
      }
      // 입질 판정
      if (phase.current === 'wait' && now - timing.current.castAt > timing.current.wait * 1000) { phase.current = 'bite'; timing.current.biteAt = now; }
      if (phase.current === 'bite' && now - timing.current.biteAt > timing.current.window * 1000) void missed();
      // 카메라·다른 사람
      const target = spectator ? ([...others.current.values()][0]?.x ?? 400) : x.current;
      cam.current += (Math.max(0, Math.min(POND_W - VIEW_W, target - VIEW_W / 2)) - cam.current) * Math.min(1, dt * 6);
      for (const o of others.current.values()) o.x += (o.tx - o.x) * Math.min(1, dt * 10);
      if (!spectator && ws.current?.readyState === 1 && now - sent > 150) { sent = now; ws.current.send(JSON.stringify({ t: 'pos', x: Math.round(x.current), y: 0, pose: phase.current === 'walk' ? (input.current.left || input.current.right ? 'run' : 'stand') : 'fish', face: face.current })); }

      // ── 그리기 ──
      const W = c.width, H = c.height, s = W / VIEW_W; const sx = (wx: number) => (wx - cam.current) * s;
      ctx.fillStyle = '#f4f1f2'; ctx.fillRect(0, 0, W, H);
      // 물
      ctx.fillStyle = '#dfe9ee'; ctx.fillRect(0, BANK * s, W, H - BANK * s);
      ctx.strokeStyle = '#c3d5de'; ctx.lineWidth = 1;
      for (let i = 0; i < 6; i++) { const yy = (BANK + 30 + i * 24) * s; ctx.beginPath(); for (let px = 0; px <= W; px += 12) ctx.lineTo(px, yy + Math.sin((px + cam.current * s) / 40 + t * 1.2 + i) * 2.5 * s); ctx.stroke(); }
      // 물가·구역
      ctx.fillStyle = '#c6b8a0'; ctx.fillRect(0, (BANK - 6) * s, W, 8 * s);
      for (const z of ZONES) {
        const zx = sx(z.x0); if (zx > W || zx + 800 * s < 0) continue;
        ctx.fillStyle = z.key === 'i' ? '#eef4f7' : z.key === 'p' ? '#cfc6c9' : z.key === 'r' ? '#d9e3c9' : z.key === 'e' ? '#cfdde6' : '#e3d9c6';
        ctx.fillRect(zx, BANK * s, 800 * s, 14 * s);
        ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${11 * s}px ui-monospace, monospace`; ctx.textAlign = 'left';
        ctx.fillText(`${z.name.toUpperCase()}${z.rod > 1 ? ` · rod ${z.rod}+` : ''}`, zx + 10 * s, (BANK - 14) * s);
        if (z.key === 'p') { ctx.fillStyle = '#6b6166'; ctx.fillRect(zx + 380 * s, (BANK - 60) * s, 60 * s, 54 * s); ctx.fillStyle = '#2b2b2b'; ctx.beginPath(); ctx.arc(zx + 410 * s, (BANK - 30) * s, 18 * s, 0, 6.29); ctx.fill(); }
        if (z.key === 'd') { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(zx + 300 * s, (BANK - 4) * s, 200 * s, 6 * s); for (let k = 0; k < 4; k++) ctx.fillRect(zx + (320 + k * 55) * s, BANK * s, 6 * s, 40 * s); }
        if (z.key === 'r') { ctx.strokeStyle = '#6b8f5a'; ctx.lineWidth = 2 * s; for (let k = 0; k < 14; k++) { const rx = zx + (40 + k * 55) * s; ctx.beginPath(); ctx.moveTo(rx, (BANK + 10) * s); ctx.lineTo(rx + Math.sin(t + k) * 3 * s, (BANK - 40 - (k % 3) * 12) * s); ctx.stroke(); } }
        if (z.key === 'i') { ctx.fillStyle = '#ffffff'; ctx.fillRect(zx, BANK * s, 800 * s, 60 * s); ctx.fillStyle = '#dfe9ee'; ctx.beginPath(); ctx.ellipse(zx + 400 * s, (BANK + 30) * s, 90 * s, 22 * s, 0, 0, 6.29); ctx.fill(); }
      }
      // 주민
      for (const r of sitting) {
        const fx = sx(r.x); if (fx < -80 || fx > W + 80) continue;
        figure(ctx, fx, BANK * s, s, 'fish', 1, '#3a2f36', t + r.seed % 7, false);
        ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(fx + 58 * s, (BANK - 52) * s); ctx.lineTo(fx + 80 * s, (BANK + 24) * s); ctx.stroke();
        ctx.fillStyle = '#ff2d55'; ctx.beginPath(); ctx.arc(fx + 80 * s, (BANK + 24 + Math.sin(t * 2 + r.seed) * 2) * s, 3 * s, 0, 6.29); ctx.fill();
        ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(`${residents[r.who].handle} ᴬᴵ`, fx, (BANK - 58) * s);
        const st = residentState(r.seed, r.zone, t);
        if (st.phase === 'catch' && st.item) { bubble(ctx, fx, (BANK - 70) * s, s, `caught ${st.item.name}`); drawGlyph(ctx, st.item.glyph, fx + 80 * s, (BANK - 10) * s, 26 * s, r.seed); }
      }
      // 다른 사람
      for (const o of others.current.values()) {
        const fx = sx(o.x); if (fx < -80 || fx > W + 80) continue;
        const pose = o.status === 'rest' ? 'sit' : o.pose === 'fish' ? 'fish' : o.pose === 'run' ? 'run' : 'stand';
        figure(ctx, fx, BANK * s, s, pose as 'fish', 1, figureColor(o.uid), t, false);
        if (pose === 'fish') { ctx.strokeStyle = figureColor(o.uid); ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(fx + 58 * s, (BANK - 52) * s); ctx.lineTo(fx + 80 * s, (BANK + 24) * s); ctx.stroke(); }
        ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(o.handle, fx, (BANK - 58) * s);
      }
      // 나
      if (!spectator) {
        const fx = sx(x.current); const ph = phase.current; const col = figureColor(me!.id);
        const pose = ph === 'walk' ? (input.current.left || input.current.right ? 'run' : 'stand') : 'fish';
        figure(ctx, fx, BANK * s, s, pose, face.current, col, t, false);
        ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(me!.handle, fx, (BANK - 58) * s);
        if (ph !== 'walk') {
          const bx = fx + 80 * s * face.current;
          const dip = ph === 'bite' ? 9 : Math.sin(t * 2) * 2;
          ctx.strokeStyle = col; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(fx + 58 * s * face.current, (BANK - 52) * s); ctx.lineTo(bx, (BANK + 24 + dip) * s); ctx.stroke();
          ctx.fillStyle = '#ff2d55'; ctx.beginPath(); ctx.arc(bx, (BANK + 24 + dip) * s, 4 * s, 0, 6.29); ctx.fill();
          if (ph === 'bite') { ctx.fillStyle = '#ff2d55'; ctx.font = `bold ${22 * s}px system-ui`; ctx.fillText('!', bx, (BANK - 4) * s); ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2 * s; ctx.beginPath(); ctx.arc(bx, (BANK + 24) * s, (10 + ((now - timing.current.biteAt) / 40) % 20) * s, 0, 6.29); ctx.stroke(); }
        }
      }
      if (now - hudAt > 250) { hudAt = now; setHud({ zone: zoneAt(spectator ? cam.current + VIEW_W / 2 : x.current), phase: phase.current, online: [...others.current.values()].filter((o) => o.status === 'active').length + (spectator ? 0 : 1) }); }
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [residents, me, spectator]);

  useEffect(() => {
    const c = canvas.current!, w = wrap.current!;
    const fit = () => { const width = Math.min(960, w.clientWidth); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (VIEW_H / VIEW_W) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (VIEW_H / VIEW_W)}px`; };
    fit(); const ro = new ResizeObserver(fit); ro.observe(w); return () => ro.disconnect();
  }, []);

  const say = () => { const body = line.trim(); if (!body || ws.current?.readyState !== 1) return; ws.current.send(JSON.stringify({ t: 'chat', body })); setLine(''); };
  const hold = (k: 'left' | 'right') => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });
  const rod = RODS[(state?.rod ?? 1) - 1]; const next = RODS[state?.rod ?? 1];
  const bookCount = state ? Object.keys(state.book).length : 0;
  const act = () => { if (phase.current === 'walk') void cast(); else if (phase.current === 'wait' || phase.current === 'bite') void hook(); else if (phase.current === 'card') { setCard(null); phase.current = 'walk'; } };

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex flex-wrap items-center justify-between gap-2 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{hud.zone.name} <span className="normal-case tracking-normal font-normal">— {hud.zone.blurb}</span></span>
        <span>{hud.online} fishing</span>
      </div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#f4f1f2]">
        <canvas ref={canvas} className="block w-full touch-none" onClick={() => { if (!TOUCH && !spectator) act(); }} />
        {card && (
          <div className="absolute inset-0 grid place-items-center bg-paper/85 p-4">
            <div className="w-full max-w-sm rounded-2xl border border-hairline bg-paper p-4 text-center shadow-[0_12px_40px_-12px_rgba(0,0,0,0.35)]">
              <CardGlyph item={card.item} seed={card.at} />
              <p className="mt-1 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em]" style={{ color: RARITY_COLOR[card.item.rarity] }}>{RARITY_NAME[card.item.rarity]} · +{card.earned}</p>
              <p className="mt-1 text-[17px] font-bold leading-snug">You caught {card.item.name}</p>
              {card.item.line && <p className="mt-1 text-[13px] text-ink-mid">{card.item.line}</p>}
              {card.newBadges.length > 0 && <p className="mt-2 text-[12.5px] font-semibold text-accent-deep">Badge: {card.newBadges.map((k) => BADGE_BY_KEY.get(k)?.name ?? k).join(', ')}</p>}
              <div className="mt-3 flex justify-center gap-2">
                <button onClick={() => void postCard()} disabled={posting || posted.current === card.at} className={`${BUTTON.ghost} inline-flex items-center gap-1.5 disabled:opacity-50`}><Upload size={13} aria-hidden /> {posted.current === card.at ? 'Posted' : posting ? 'Posting…' : 'Post it'}</button>
                <button onClick={() => { setCard(null); phase.current = 'walk'; }} className={BUTTON.primary}>Keep fishing</button>
              </div>
            </div>
          </div>
        )}
        {spectator && (
          <div className="absolute inset-x-0 bottom-0 flex items-center justify-between bg-paper/90 px-3 py-2 text-[12.5px]">
            <span>You are watching the pond. Log in to sit down.</span>
            <a href="/login?mode=signup" className="font-bold underline underline-offset-2">Log in</a>
          </div>
        )}
        {!spectator && TOUCH && !card && (
          <div className="absolute inset-x-0 bottom-0 flex justify-between p-2">
            <div className="flex gap-2"><button {...hold('left')} className="size-14 rounded-full bg-ink/70 text-xl text-paper">←</button><button {...hold('right')} className="size-14 rounded-full bg-ink/70 text-xl text-paper">→</button></div>
            <button onPointerDown={act} className="h-14 rounded-full bg-accent px-5 text-[14px] font-bold text-paper">{hud.phase === 'walk' ? 'Cast' : 'Hook!'}</button>
          </div>
        )}
      </div>
      {!spectator && (
        <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-[12px] text-ink-mid">
          <span><b>{rod.name}</b> (rod {rod.level})</span>
          <span><b>{state?.coins ?? 0}</b> coins</span>
          <span>bait: {BAITS.map((b) => (
            <button key={b.key} onClick={() => setBait(bait === b.key ? null : b.key)} className={`ml-1 rounded-full border px-2 py-0.5 text-[11.5px] font-bold ${bait === b.key ? 'border-ink bg-ink text-paper' : 'border-hairline'}`}>{b.name} {state?.bait[b.key] ?? 0}</button>
          ))}</span>
          <button onClick={() => setShop((v) => !v)} className="inline-flex items-center gap-1 font-bold underline underline-offset-2"><ShoppingBag size={12} /> shop</button>
          <button onClick={() => setBook((v) => !v)} className="inline-flex items-center gap-1 font-bold underline underline-offset-2"><Fish size={12} /> book {bookCount}/{ITEM_LIST.length}</button>
          {!TOUCH && <span className="ml-auto font-mono text-[10.5px] text-ink-soft">← → walk · SPACE cast, SPACE again when the float dips</span>}
        </div>
      )}
      {message && <p role="alert" className="mt-1 text-[12.5px] font-semibold text-accent-deep">{message}</p>}
      {shop && state && (
        <div className="mt-2 rounded-xl border border-hairline bg-paper p-3 text-[13px]">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Shop</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {next ? <button onClick={() => void buy('rod')} className={BUTTON.ghost}>Upgrade to {next.name} — {next.price}</button> : <span className="text-ink-soft">You have the rod.</span>}
            {BAITS.map((b) => <button key={b.key} onClick={() => void buy(b.key)} className={BUTTON.ghost} title={b.blurb}>5 {b.name} — {b.price * 5}</button>)}
          </div>
          <p className="mt-2 text-[11.5px] text-ink-soft">Rods: wider hook window, shorter waits, better luck, deeper spots. {ZONES.filter((z) => z.rod > 1).map((z) => `${z.name} needs rod ${z.rod}`).join(' · ')}.</p>
        </div>
      )}
      {book && state && (
        <div className="mt-2 max-h-72 overflow-y-auto rounded-xl border border-hairline bg-paper p-3 text-[12.5px]">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Book · {bookCount} of {ITEM_LIST.length}</p>
          <ul className="mt-2 grid gap-x-4 gap-y-0.5 sm:grid-cols-2">
            {ITEM_LIST.map((it) => (
              <li key={it.key} className={state.book[it.key] ? '' : 'text-ink-soft opacity-60'}>
                <span className="mr-1.5 inline-block size-2 rounded-full" style={{ background: RARITY_COLOR[it.rarity] }} />
                {state.book[it.key] ? `${it.name} ×${state.book[it.key]}` : '???'}
              </li>
            ))}
          </ul>
          {state.badges.length > 0 && <p className="mt-3 text-[12px]"><b>Badges:</b> {state.badges.map((k) => BADGE_BY_KEY.get(k)?.name ?? k).join(' · ')}</p>}
        </div>
      )}
      <div className="mt-3 rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[12.5px]">
        <div className="max-h-24 overflow-y-auto">{chats.length === 0 ? <span className="text-ink-soft">…</span> : chats.map((c, i) => <div key={i}><b>{c.who}</b> {c.body}</div>)}</div>
        {!spectator && <div className="mt-1 flex gap-1.5"><input value={line} onChange={(e) => setLine(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') say(); }} maxLength={140} placeholder="say something" className="min-w-0 flex-1 rounded border border-hairline bg-surface px-2 py-1 outline-none focus:border-ink" /><button onClick={say} className="rounded border border-hairline px-2 font-bold">send</button></div>}
      </div>
    </div>
  );
}

function CardGlyph({ item, seed }: { item: Item; seed: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => { const c = ref.current!; c.width = 320; c.height = 200; const ctx = c.getContext('2d')!; ctx.clearRect(0, 0, 320, 200); drawGlyph(ctx, item.glyph, 160, 100, 150, seed); }, [item, seed]);
  return <canvas ref={ref} className="mx-auto h-[100px] w-[160px]" />;
}
function bubble(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) {
  ctx.font = `${11 * s}px system-ui, sans-serif`; ctx.textAlign = 'left';
  const t = text.length > 44 ? `${text.slice(0, 42)}…` : text;
  const w = ctx.measureText(t).width + 14 * s, h = 20 * s;
  const bx = Math.min(ctx.canvas.width - w - 4, Math.max(4, x - w / 2)), by = y - 22 * s;
  ctx.fillStyle = '#ffffff'; ctx.strokeStyle = '#b9b1b6'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.roundRect(bx, by, w, h, 6 * s); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#1b0c15'; ctx.fillText(t, bx + 7 * s, by + 14 * s);
}
void ITEM_BY_KEY;
