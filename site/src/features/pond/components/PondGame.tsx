'use client';
import { useEffect, useRef, useState } from 'react';
import { Fish, ShoppingBag, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { figure } from '@/lib/stickman';
import { figureColor, hash, rng } from '@/lib/tower';
import { drawGlyph } from '@/lib/pond-glyph';
import { BADGE_BY_KEY, BAITS, DEPTH_PX, ITEM_LIST, POND_W, RARITY_COLOR, RARITY_NAME, RODS, SHOP_BADGES, residentState, shadows, sittingResidents, ZONES, ZONE_W, zoneAt, type BaitKey, type Item } from '@/lib/pond';

/**
 * Pond — 화면. 2.5D 물가: 좌우로 걷고(←→) 앞뒤로도 걷고(↑↓) 뛴다(SPACE). 멀수록 작게, 앞의 것이 뒤의 것을 가린다.
 * 던지기(C 를 누르고 있으면 멀리) → 찌가 물에 → 기다림 → 찌가 잠기면 C → 릴링 미니게임(막대 안에 물고기를 가두며 게이지) → 카드.
 * 물속엔 그림자가 돌아다닌다 — 그 근처에 찌를 넣으면 헛탕이 준다. 규칙·표·뽑기는 lib/pond + /api/pond.
 */
export interface ResidentLite { id: number; handle: string }
interface Me { id: number; handle: string }
interface State { rod: number; coins: number; casts: number; bait: Partial<Record<BaitKey, number>>; book: Record<string, number>; badges: string[] }
interface Other { uid: number; handle: string; x: number; tx: number; d: number; td: number; pose: string; status: 'active' | 'rest' }
interface Catch { item: Item; earned: number; newBadges: string[]; at: number }
type Phase = 'walk' | 'charge' | 'cast' | 'wait' | 'bite' | 'reel' | 'busy' | 'card';

const VIEW_W = 960, VIEW_H = 460, BANK = 300, BANK_TOP = BANK - DEPTH_PX;
const TOUCH = typeof window !== 'undefined' && 'ontouchstart' in window;
const depthY = (d: number) => BANK_TOP + d * DEPTH_PX;      // 깊이(0 뒤 ~ 1 물가) → 화면 y
const depthS = (d: number) => 0.72 + 0.28 * d;              // 멀수록 작게

export function PondGame({ residents, me, initial, memes }: { residents: ResidentLite[]; me: Me | null; initial: State | null; memes: string[] }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const wrap = useRef<HTMLDivElement>(null);
  const ws = useRef<WebSocket | null>(null);
  const body = useRef({ x: 160, d: 0.7, z: 0, vz: 0, face: 1 as 1 | -1, moving: false });
  const input = useRef({ left: false, right: false, up: false, down: false, jump: false, act: false });
  const phase = useRef<Phase>('walk');
  const cast = useRef({ charge: 0, bx: 0, bd: 0, at: 0, wait: 0, window: 0, biteAt: 0, difficulty: 0.3 });
  const reel = useRef({ fish: 0.5, fv: 0, bar: 0.5, bv: 0, prog: 0.3, at: 0 });
  const others = useRef(new Map<number, Other>());
  const cam = useRef(0);
  const [state, setState] = useState<State | null>(initial);
  const [bait, setBait] = useState<BaitKey | null>('worm');
  const [card, setCard] = useState<Catch | null>(null);
  const [message, setMessage] = useState('');
  const [hud, setHud] = useState({ zone: ZONES[0], phase: 'walk' as Phase, online: 0 });
  const [chats, setChats] = useState<{ who: string; body: string }[]>([]);
  const [line, setLine] = useState('');
  const [panel, setPanel] = useState<'none' | 'shop' | 'book'>('none');
  const posted = useRef<number | null>(null);
  const [posting, setPosting] = useState(false);
  const spectator = !me;
  void memes;

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
          if (me && uid === me.id) { if (m.t === 'init') { body.current.x = Number(u.x) || 160; body.current.d = Math.min(1, Math.max(0, (Number(u.y) || 700) / 1000)); cam.current = body.current.x - VIEW_W / 2; } return; }
          const prev = map.get(uid); const d = Math.min(1, Math.max(0, (Number(u.y) || 700) / 1000));
          map.set(uid, { uid, handle: String(u.handle ?? ''), x: prev?.x ?? (Number(u.x) || 0), tx: Number(u.x) || 0, d: prev?.d ?? d, td: d, pose: String(u.pose ?? 'stand'), status: u.status === 'rest' ? 'rest' : 'active' });
        };
        if (m.t === 'init') { map.clear(); for (const u of m.users as Record<string, unknown>[]) put(u); }
        else if (m.t === 'user') put(m.u as Record<string, unknown>);
        else if (m.t === 'pos') { const o = map.get(Number(m.uid)); if (o) { o.tx = Number(m.x); o.td = Math.min(1, Math.max(0, Number(m.y) / 1000)); o.pose = String(m.pose); o.status = 'active'; } }
        else if (m.t === 'rest') { const o = map.get(Number(m.uid)); if (o) { o.status = 'rest'; o.pose = 'sit'; } }
        else if (m.t === 'leave') map.delete(Number(m.uid));
        else if (m.t === 'chat') setChats((c) => [...c.slice(-7), { who: String(m.handle), body: String(m.body) }]);
      };
      sock.onclose = () => { if (alive) setTimeout(connect, Math.min(15000, 1000 * 2 ** retry++)); };
    };
    connect();
    return () => { alive = false; sock?.close(); };
  }, [me]);

  // ── API ──
  const api = async (b: Record<string, unknown>) => {
    const res = await fetch('/api/pond', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b) });
    const d = await res.json() as Record<string, unknown> & { message?: string };
    if (!res.ok) { setMessage(d.message ?? 'Hm.'); return null; }
    return d;
  };
  const doCast = async (charge: number) => {
    const b = body.current; const zone = zoneAt(b.x);
    if ((state?.rod ?? 1) < zone.rod) { setMessage(`${zone.name} needs rod level ${zone.rod}. Yours is ${state?.rod ?? 1}.`); phase.current = 'walk'; return; }
    phase.current = 'cast'; setMessage(''); setCard(null);
    // 찌 자리: 누른 만큼 멀리(물속 깊이 0.1~1), 얼굴 방향으로 조금 옆으로
    const far = 0.15 + 0.85 * charge;
    const bx = Math.max(zone.x0 + 20, Math.min(zone.x0 + ZONE_W - 20, b.x + b.face * (30 + 70 * charge)));
    const sh = shadows(zone, Date.now() / 1000);
    const near = sh.some((s) => Math.abs(s.x - bx) < 55 && Math.abs(s.d - far) < 0.22);
    cast.current = { ...cast.current, charge, bx, bd: far, at: performance.now() };
    const d = await api({ action: 'cast', zone: zone.key, bait, far, near });
    if (!d) { phase.current = 'walk'; return; }
    setState((s) => (s ? { ...s, bait: d.bait as State['bait'], casts: s.casts + 1 } : s));
    cast.current = { ...cast.current, at: performance.now(), wait: Number(d.wait), window: Number(d.window), difficulty: Number(d.difficulty) || 0.3, biteAt: 0 };
    phase.current = 'wait';
  };
  const startReel = () => {
    const diff = cast.current.difficulty;
    reel.current = { fish: 0.5, fv: 0, bar: 0.5, bv: 0, prog: 0.35, at: performance.now() };
    phase.current = 'reel'; setMessage(diff > 0.65 ? 'It is strong.' : '');
  };
  const finish = async (ok: boolean) => {
    phase.current = 'busy';
    const d = await api({ action: ok ? 'land' : 'miss' });
    if (!d) { phase.current = 'walk'; return; }
    setState(d as unknown as State);
    const item = ok ? (d.item as Item | null) : null;
    if (item) { setCard({ item, earned: Number(d.earned), newBadges: (d.newBadges as string[]) ?? [], at: Date.now() }); phase.current = 'card'; ws.current?.send(JSON.stringify({ t: 'chat', body: `caught ${item.name}` })); }
    else { setMessage(ok ? 'It got away.' : 'It got away.'); phase.current = 'walk'; }
  };
  const buy = async (what: string) => { const d = await api({ action: 'buy', what }); if (d) { setState(d as unknown as State); setMessage(''); } };

  /** 벽에 올리기 — 카드를 그림으로 찍어 짤로 게시 */
  const postCard = async () => {
    if (!card || !me || posted.current === card.at) return;
    setPosting(true);
    const c = document.createElement('canvas'); c.width = 900; c.height = 900; const ctx = c.getContext('2d')!;
    ctx.fillStyle = '#f4f1f2'; ctx.fillRect(0, 0, 900, 900); ctx.fillStyle = '#dfe9ee'; ctx.fillRect(0, 520, 900, 380);
    drawGlyph(ctx, card.item.glyph, 450, 420, 380, card.at, '#1b0c15', card.item.key);
    ctx.fillStyle = RARITY_COLOR[card.item.rarity]; ctx.font = 'bold 26px ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillText(RARITY_NAME[card.item.rarity].toUpperCase(), 450, 700);
    ctx.fillStyle = '#1b0c15'; ctx.font = 'bold 44px system-ui, sans-serif';
    const words = `${me.handle} caught ${card.item.name}`.split(' '); const lines: string[] = []; let cur = '';
    for (const w of words) { const t = cur ? `${cur} ${w}` : w; if (ctx.measureText(t).width > 800 && cur) { lines.push(cur); cur = w; } else cur = t; } lines.push(cur);
    lines.forEach((l, i) => ctx.fillText(l, 450, 760 + i * 52));
    ctx.fillStyle = '#8f8489'; ctx.font = '22px ui-monospace, monospace'; ctx.fillText('population.town/pond', 450, 870);
    const blob = await new Promise<Blob | null>((ok) => c.toBlob(ok, 'image/png'));
    if (!blob) { setPosting(false); return; }
    const fd = new FormData(); fd.append('image', new File([blob], 'catch.png', { type: 'image/png' })); fd.append('kind', 'meme');
    const up = await (await fetch('/api/upload', { method: 'POST', body: fd })).json() as { url?: string };
    if (up.url) {
      const res = await fetch('/api/memes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ png: up.url, caption: `${me.handle} caught ${card.item.name}` }) });
      if (res.ok) { posted.current = card.at; setMessage('Posted to the wall (and your blog).'); }
    }
    setPosting(false);
  };

  // ── 입력: ←→↑↓ 걷기, SPACE 점프, C 던지기(누르면 힘)/챔질/릴링(누르고 있기) ──
  useEffect(() => {
    if (spectator) return;
    const typing = () => { const el = document.activeElement; return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement; };
    const set = (k: string, v: boolean, e: KeyboardEvent) => {
      const i = input.current;
      if (k === 'ArrowLeft' || k === 'a') i.left = v; else if (k === 'ArrowRight' || k === 'd') i.right = v;
      else if (k === 'ArrowUp' || k === 'w') i.up = v; else if (k === 'ArrowDown' || k === 's') i.down = v;
      else if (k === ' ') i.jump = v; else if (k === 'c' || k === 'C' || k === 'Enter') i.act = v; else return;
      e.preventDefault();
    };
    const kd = (e: KeyboardEvent) => { if (!typing()) set(e.key, true, e); };
    const ku = (e: KeyboardEvent) => { if (!typing()) set(e.key, false, e); };
    window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, [spectator]);

  // ── 루프 ──
  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    let raf = 0, last = performance.now(), sent = 0, hudAt = 0, actWas = false, jumpWas = false;
    const hour = () => Math.floor(Date.now() / 3600000);
    let sitting = sittingResidents(hour(), residents.length).map((r) => ({ ...r, d: 0.85 + (r.seed % 15) / 100 })), sittingHour = hour();
    const scenery = SCENERY();
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.1, (now - last) / 1000); last = now; const t = Date.now() / 1000;
      if (hour() !== sittingHour) { sittingHour = hour(); sitting = sittingResidents(sittingHour, residents.length).map((r) => ({ ...r, d: 0.85 + (r.seed % 15) / 100 })); }
      const b = body.current, i = input.current, ph = phase.current;
      // 걷기·점프 — 낚시 중엔 못 움직인다
      if (!spectator) {
        if (ph === 'walk' || ph === 'charge') {
          const dx = (i.right ? 1 : 0) - (i.left ? 1 : 0), dd = (i.down ? 1 : 0) - (i.up ? 1 : 0);
          if (ph === 'walk' && (dx || dd)) { b.x = Math.max(30, Math.min(POND_W - 30, b.x + dx * 230 * dt)); b.d = Math.max(0, Math.min(1, b.d + dd * 1.6 * dt)); if (dx) b.face = dx as 1 | -1; }
          b.moving = ph === 'walk' && !!(dx || dd);
          if (i.jump && !jumpWas && b.z === 0 && ph === 'walk') b.vz = 560;
        }
        if (b.z > 0 || b.vz > 0) { b.vz -= 1900 * dt; b.z = Math.max(0, b.z + b.vz * dt); if (b.z === 0) b.vz = 0; }
        // 던지기: C 누르는 동안 힘, 놓으면 던짐
        if (ph === 'walk' && i.act && !actWas && b.z === 0) { phase.current = 'charge'; cast.current.charge = 0; }
        if (ph === 'charge') { if (i.act) cast.current.charge = Math.min(1, cast.current.charge + dt * 0.9); else void doCast(cast.current.charge); }
        if (ph === 'wait' && now - cast.current.at > cast.current.wait * 1000) { phase.current = 'bite'; cast.current.biteAt = now; }
        if (ph === 'wait' && i.act && !actWas) { void finish(false); setMessage('Too early. Whatever it was, it left.'); }
        if (ph === 'bite') { if (i.act && !actWas) startReel(); else if (now - cast.current.biteAt > cast.current.window * 1000) { void finish(false); setMessage('Too slow.'); } }
        // 릴링: 막대(누르면 올라감, 놓으면 내려감) 안에 물고기(난이도만큼 날뜀)를 두면 게이지가 찬다
        if (ph === 'reel') {
          const r = reel.current, diff = cast.current.difficulty;
          const seed = Math.floor((now - r.at) / (420 - diff * 260));
          const want = rng(seed + Math.floor(cast.current.at))() ;
          r.fv += ((want - r.fish) * (2 + diff * 6) - r.fv * 1.2) * dt; r.fish = Math.max(0.03, Math.min(0.97, r.fish + r.fv * dt * (0.8 + diff)));
          r.bv += ((i.act ? 2.6 : -2.2) - r.bv * 2.2) * dt; r.bar = Math.max(0, Math.min(1, r.bar + r.bv * dt));
          const half = (0.2 - diff * 0.09) * (RODS[(state?.rod ?? 1) - 1].window);
          const inside = Math.abs(r.fish - (r.bar * (1 - 2 * half) + half)) < half;
          r.prog += (inside ? 0.28 : -(0.16 + diff * 0.14)) * dt;
          if (r.prog >= 1) void finish(true); else if (r.prog <= 0) { void finish(false); setMessage('It broke off.'); }
        }
        actWas = i.act; jumpWas = i.jump;
        if (ws.current?.readyState === 1 && now - sent > 150) { sent = now; ws.current.send(JSON.stringify({ t: 'pos', x: Math.round(b.x), y: Math.round(b.d * 1000), pose: ph === 'walk' || ph === 'charge' ? (b.z > 0 ? 'jump' : b.moving ? 'run' : 'stand') : 'fish', face: b.face })); }
      }
      // 카메라·다른 사람
      const target = spectator ? ([...others.current.values()][0]?.x ?? 400) : b.x;
      cam.current += (Math.max(0, Math.min(POND_W - VIEW_W, target - VIEW_W / 2)) - cam.current) * Math.min(1, dt * 6);
      for (const o of others.current.values()) { o.x += (o.tx - o.x) * Math.min(1, dt * 10); o.d += (o.td - o.d) * Math.min(1, dt * 10); }

      // ── 그리기 ──
      const W = c.width, H = c.height, s = W / VIEW_W; const sx = (wx: number) => (wx - cam.current) * s;
      // 하늘·언덕(시차)
      ctx.fillStyle = '#eef0f2'; ctx.fillRect(0, 0, W, BANK_TOP * s);
      ctx.fillStyle = '#d9dfd0'; ctx.beginPath(); ctx.moveTo(0, BANK_TOP * s);
      for (let px = 0; px <= W; px += 20) ctx.lineTo(px, (BANK_TOP - 30 - 22 * Math.sin((px + cam.current * s * 0.3) / 140) - 10 * Math.sin((px + cam.current * s * 0.3) / 47)) * s);
      ctx.lineTo(W, BANK_TOP * s); ctx.closePath(); ctx.fill();
      // 물가(면): 뒤는 어둡게, 앞은 밝게 — 깊이가 보인다
      const grd = ctx.createLinearGradient(0, BANK_TOP * s, 0, BANK * s); grd.addColorStop(0, '#b9c39e'); grd.addColorStop(1, '#d6dcbc');
      ctx.fillStyle = grd; ctx.fillRect(0, BANK_TOP * s, W, DEPTH_PX * s);
      for (const z of ZONES) { // 구역 바닥
        const zx = sx(z.x0); if (zx > W || zx + ZONE_W * s < 0) continue;
        if (z.key === 'i') { ctx.fillStyle = '#eef3f5'; ctx.fillRect(zx, BANK_TOP * s, ZONE_W * s, DEPTH_PX * s); }
        if (z.key === 'p') { ctx.fillStyle = '#c9c3c6'; ctx.fillRect(zx, (BANK - 40) * s, ZONE_W * s, 40 * s); }
        if (z.key === 'd') { ctx.fillStyle = '#c9b48a'; ctx.fillRect(zx, (BANK - 30) * s, ZONE_W * s, 30 * s); }
        ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${11 * s}px ui-monospace, monospace`; ctx.textAlign = 'left';
        ctx.fillText(`${z.name.toUpperCase()}${z.rod > 1 ? ` · rod ${z.rod}+` : ''}`, zx + 10 * s, (BANK_TOP - 8) * s);
      }
      // 물
      ctx.fillStyle = '#c9dde6'; ctx.fillRect(0, BANK * s, W, H - BANK * s);
      const wg = ctx.createLinearGradient(0, BANK * s, 0, H); wg.addColorStop(0, 'rgba(255,255,255,0.25)'); wg.addColorStop(1, 'rgba(60,90,120,0.35)'); ctx.fillStyle = wg; ctx.fillRect(0, BANK * s, W, H - BANK * s);
      ctx.strokeStyle = 'rgba(255,255,255,0.5)'; ctx.lineWidth = 1;
      for (let k = 0; k < 7; k++) { const yy = (BANK + 14 + k * 20) * s; ctx.beginPath(); for (let px = 0; px <= W; px += 14) ctx.lineTo(px, yy + Math.sin((px + cam.current * s) / 46 + t * 1.3 + k) * 2.5 * s); ctx.stroke(); }
      // 물속 그림자 (구역별)
      for (const z of ZONES) { if (sx(z.x0) > W || sx(z.x0 + ZONE_W) < 0) continue; for (const sh of shadows(z, t)) { const fx = sx(sh.x), fy = (BANK + 10 + sh.d * 110) * s; ctx.fillStyle = 'rgba(30,50,70,0.28)'; ctx.beginPath(); ctx.ellipse(fx, fy, sh.size * s, sh.size * 0.4 * s, Math.sin(t * 0.7 + sh.x) * 0.3, 0, 6.29); ctx.fill(); } }
      // 장면 요소 + 사람들: 깊이 순으로 (뒤 → 앞)
      type Draw = { d: number; f: () => void };
      const layer: Draw[] = [];
      for (const it of scenery) { const fx = sx(it.x); if (fx < -120 || fx > W + 120) continue; layer.push({ d: it.d, f: () => prop(ctx, it.kind, fx, depthY(it.d) * s, depthS(it.d) * s, it.seed, t) }); }
      for (const r of sitting) {
        const fx = sx(r.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: r.d, f: () => {
          const fy = depthY(r.d) * s, fs = depthS(r.d) * s;
          figure(ctx, fx, fy, fs, 'fish', 1, '#3a2f36', t + r.seed % 7, false);
          ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(fx + 58 * fs, fy - 52 * fs); ctx.lineTo(fx + 90 * fs, (BANK + 30) * s); ctx.stroke();
          ctx.fillStyle = '#ff2d55'; ctx.beginPath(); ctx.arc(fx + 90 * fs, (BANK + 30 + Math.sin(t * 2 + r.seed) * 2) * s, 3 * s, 0, 6.29); ctx.fill();
          name(ctx, fx, fy - 58 * fs, s, `${residents[r.who].handle} ᴬᴵ`);
          const st = residentState(r.seed, r.zone, t);
          if (st.phase === 'catch' && st.item) { bubble(ctx, fx, fy - 70 * fs, s, `caught ${st.item.name}`); drawGlyph(ctx, st.item.glyph, fx + 90 * fs, (BANK - 6) * s, 26 * s, r.seed, '#1b0c15', st.item.key); }
        } });
      }
      for (const o of others.current.values()) {
        const fx = sx(o.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: o.d, f: () => {
          const fy = depthY(o.d) * s, fs = depthS(o.d) * s; const col = figureColor(o.uid);
          const pose = o.status === 'rest' ? 'sit' : o.pose === 'fish' ? 'fish' : o.pose === 'run' ? 'run' : o.pose === 'jump' ? 'jump' : 'stand';
          figure(ctx, fx, fy, fs, pose as 'fish', 1, col, t, false);
          if (pose === 'fish') { ctx.strokeStyle = col; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(fx + 58 * fs, fy - 52 * fs); ctx.lineTo(fx + 90 * fs, (BANK + 30) * s); ctx.stroke(); }
          name(ctx, fx, fy - 58 * fs, s, o.handle);
        } });
      }
      if (!spectator) {
        layer.push({ d: b.d, f: () => {
          const fx = sx(b.x), fy = (depthY(b.d) - b.z) * s, fs = depthS(b.d) * s; const col = figureColor(me!.id); const p = phase.current;
          const pose = p === 'walk' ? (b.z > 0 ? 'jump' : b.moving ? 'run' : 'stand') : p === 'charge' ? 'charge' : 'fish';
          if (b.z > 0) { ctx.fillStyle = 'rgba(0,0,0,0.15)'; ctx.beginPath(); ctx.ellipse(fx, depthY(b.d) * s, 12 * fs, 4 * fs, 0, 0, 6.29); ctx.fill(); }
          figure(ctx, fx, fy, fs, pose, b.face, col, t, false);
          name(ctx, fx, fy - 58 * fs, s, me!.handle);
          if (p === 'charge') { const w = 60 * s; ctx.fillStyle = '#ffffff'; ctx.fillRect(fx - w / 2, fy - 72 * fs, w, 6 * s); ctx.fillStyle = '#ff2d55'; ctx.fillRect(fx - w / 2, fy - 72 * fs, w * cast.current.charge, 6 * s); }
          if (p === 'wait' || p === 'bite' || p === 'reel' || p === 'busy' || p === 'card' || p === 'cast') {
            const cx = sx(cast.current.bx), cy = (BANK + 10 + cast.current.bd * 110) * s;
            const dip = p === 'bite' ? 7 * s : Math.sin(t * 2) * 2 * s;
            ctx.strokeStyle = col; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(fx + 58 * fs * b.face, fy - 52 * fs); ctx.quadraticCurveTo((fx + cx) / 2, fy - 90 * fs, cx, cy + dip); ctx.stroke();
            ctx.fillStyle = '#ff2d55'; ctx.beginPath(); ctx.arc(cx, cy + dip, 4 * s, 0, 6.29); ctx.fill();
            ctx.fillStyle = '#ffffff'; ctx.beginPath(); ctx.arc(cx, cy + dip - 3 * s, 2.5 * s, 0, 6.29); ctx.fill();
            if (p === 'bite') { ctx.fillStyle = '#ff2d55'; ctx.font = `bold ${22 * s}px system-ui`; ctx.textAlign = 'center'; ctx.fillText('!', cx, cy - 14 * s); ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2 * s; ctx.beginPath(); ctx.ellipse(cx, cy, (10 + ((now - cast.current.biteAt) / 40) % 20) * s, (4 + ((now - cast.current.biteAt) / 100) % 8) * s, 0, 0, 6.29); ctx.stroke(); }
          }
        } });
      }
      layer.sort((a, bb) => a.d - bb.d).forEach((l) => l.f());
      // 릴링 미니게임 — 오른쪽 막대
      if (phase.current === 'reel') {
        const r = reel.current, diff = cast.current.difficulty; const bx = W - 60 * s, by = 40 * s, bh = (VIEW_H - 120) * s, bw = 22 * s;
        ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.fillRect(bx - 8 * s, by - 8 * s, bw + 34 * s, bh + 16 * s);
        ctx.fillStyle = '#e9e6e8'; ctx.fillRect(bx, by, bw, bh);
        const half = (0.2 - diff * 0.09) * RODS[(state?.rod ?? 1) - 1].window; const center = r.bar * (1 - 2 * half) + half;
        ctx.fillStyle = '#7cc47c'; ctx.fillRect(bx, by + (1 - (center + half)) * bh, bw, half * 2 * bh);
        drawGlyph(ctx, 'fish', bx + bw / 2, by + (1 - r.fish) * bh, 26 * s, 3, '#1b0c15', 'fish');
        ctx.fillStyle = '#d7d2d5'; ctx.fillRect(bx + bw + 6 * s, by, 8 * s, bh); ctx.fillStyle = '#ff2d55'; ctx.fillRect(bx + bw + 6 * s, by + (1 - r.prog) * bh, 8 * s, r.prog * bh);
        ctx.fillStyle = '#1b0c15'; ctx.font = `bold ${11 * s}px ui-monospace, monospace`; ctx.textAlign = 'right'; ctx.fillText('HOLD C', bx - 12 * s, by + 12 * s);
      }
      if (now - hudAt > 250) { hudAt = now; setHud({ zone: zoneAt(spectator ? cam.current + VIEW_W / 2 : b.x), phase: phase.current, online: [...others.current.values()].filter((o) => o.status === 'active').length + (spectator ? 0 : 1) }); }
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [residents, me, spectator, state?.rod]);

  useEffect(() => {
    const c = canvas.current!, w = wrap.current!;
    const fit = () => { const width = Math.min(960, w.clientWidth); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (VIEW_H / VIEW_W) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (VIEW_H / VIEW_W)}px`; };
    fit(); const ro = new ResizeObserver(fit); ro.observe(w); return () => ro.disconnect();
  }, []);

  const say = () => { const b = line.trim(); if (!b || ws.current?.readyState !== 1) return; ws.current.send(JSON.stringify({ t: 'chat', body: b })); setLine(''); };
  const hold = (k: 'left' | 'right' | 'up' | 'down' | 'jump' | 'act') => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });
  const rod = RODS[(state?.rod ?? 1) - 1]; const next = RODS[state?.rod ?? 1];
  const bookCount = state ? Object.keys(state.book).length : 0;

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex flex-wrap items-center justify-between gap-2 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{hud.zone.name} <span className="font-normal normal-case tracking-normal">— {hud.zone.blurb}</span></span>
        <span>{hud.online} fishing</span>
      </div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#eef0f2]">
        <canvas ref={canvas} className="block w-full touch-none" />
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
            <span>You are watching the pond. Log in to walk down to the water.</span>
            <a href="/login?mode=signup" className="font-bold underline underline-offset-2">Log in</a>
          </div>
        )}
        {!spectator && TOUCH && !card && (
          <div className="absolute inset-x-0 bottom-0 flex items-end justify-between p-2">
            <div className="grid grid-cols-3 gap-1">
              <span /><button {...hold('up')} className="size-12 rounded-full bg-ink/70 text-paper">↑</button><span />
              <button {...hold('left')} className="size-12 rounded-full bg-ink/70 text-paper">←</button><button {...hold('down')} className="size-12 rounded-full bg-ink/70 text-paper">↓</button><button {...hold('right')} className="size-12 rounded-full bg-ink/70 text-paper">→</button>
            </div>
            <div className="flex gap-2">
              <button {...hold('jump')} className="size-14 rounded-full bg-ink/70 text-paper">Jump</button>
              <button {...hold('act')} className="h-14 rounded-full bg-accent px-5 text-[14px] font-bold text-paper">{hud.phase === 'walk' ? 'Cast' : hud.phase === 'reel' ? 'Reel' : 'Hook'}</button>
            </div>
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
          <button onClick={() => setPanel(panel === 'shop' ? 'none' : 'shop')} className="inline-flex items-center gap-1 font-bold underline underline-offset-2"><ShoppingBag size={12} /> shop</button>
          <button onClick={() => setPanel(panel === 'book' ? 'none' : 'book')} className="inline-flex items-center gap-1 font-bold underline underline-offset-2"><Fish size={12} /> book {bookCount}/{ITEM_LIST.length}</button>
          {!TOUCH && <span className="ml-auto font-mono text-[10.5px] text-ink-soft">← → ↑ ↓ walk · SPACE jump · hold C to cast (longer = farther, near a shadow is better) · C when the float dips · hold C to keep the fish in the bar</span>}
        </div>
      )}
      {message && <p role="alert" className="mt-1 text-[12.5px] font-semibold text-accent-deep">{message}</p>}
      {panel === 'shop' && state && (
        <div className="mt-2 rounded-xl border border-hairline bg-paper p-3 text-[13px]">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Shop · {state.coins} coins</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {next ? <button onClick={() => void buy('rod')} className={BUTTON.ghost}>Upgrade to {next.name} — {next.price}</button> : <span className="text-ink-soft">You have the rod.</span>}
            {BAITS.map((b) => <button key={b.key} onClick={() => void buy(b.key)} className={BUTTON.ghost} title={b.blurb}>5 {b.name} — {b.price * 5}</button>)}
          </div>
          <p className="mt-2 text-[11.5px] text-ink-soft">Rods: wider hook window, calmer reeling, shorter waits, better luck, deeper spots ({ZONES.filter((z) => z.rod > 1).map((z) => `${z.name} needs rod ${z.rod}`).join(' · ')}).</p>
          <p className="mt-3 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Badges — worn on your page and your blog</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {SHOP_BADGES.map((b) => state.badges.includes(b.key)
              ? <span key={b.key} className="rounded-full border border-ink bg-ink px-3 py-1 text-[12px] font-bold text-paper" title={b.blurb}>{b.name} ✓</span>
              : <button key={b.key} onClick={() => void buy(`badge:${b.key}`)} className={BUTTON.ghost} title={b.blurb}>{b.name} — {b.price}</button>)}
          </div>
        </div>
      )}
      {panel === 'book' && state && (
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

// ── 지형 소품 — 구역마다 다르게, 씨앗으로 고정 ──
type PropKind = 'tree' | 'pine' | 'rock' | 'bush' | 'hut' | 'boat' | 'pipe' | 'pier' | 'tent' | 'snowman' | 'sign' | 'reed' | 'stump' | 'lamp' | 'bench';
function SCENERY(): { kind: PropKind; x: number; d: number; seed: number }[] {
  const out: { kind: PropKind; x: number; d: number; seed: number }[] = [];
  const r = rng(hash('pond:scenery'));
  const put = (kind: PropKind, x: number, d: number) => out.push({ kind, x, d, seed: Math.floor(r() * 1e6) });
  for (let x = 40; x < POND_W; x += 90 + r() * 120) put(r() < 0.6 ? 'tree' : 'pine', x, r() * 0.18);        // 뒷줄 나무
  const Z = (k: string) => ZONES.find((z) => z.key === k)!.x0;
  put('hut', Z('d') + 120, 0.25); put('bench', Z('d') + 330, 0.55); put('lamp', Z('d') + 520, 0.4); put('sign', Z('d') + 40, 0.6); put('pier', Z('d') + 600, 1);
  for (let i = 0; i < 9; i++) put('reed', Z('r') + 40 + i * 85 + r() * 30, 0.75 + r() * 0.25); put('stump', Z('r') + 300, 0.35); put('boat', Z('r') + 560, 0.98); put('bush', Z('r') + 150, 0.3);
  put('pipe', Z('p') + 380, 0.95); put('rock', Z('p') + 120, 0.5); put('rock', Z('p') + 650, 0.6); put('sign', Z('p') + 40, 0.5); put('bush', Z('p') + 520, 0.25);
  put('pier', Z('e') + 200, 1); put('rock', Z('e') + 500, 0.45); put('lamp', Z('e') + 700, 0.35); put('sign', Z('e') + 40, 0.55); put('bench', Z('e') + 600, 0.6);
  put('tent', Z('i') + 150, 0.35); put('snowman', Z('i') + 400, 0.5); put('pine', Z('i') + 600, 0.3); put('sign', Z('i') + 40, 0.5); put('stump', Z('i') + 700, 0.7);
  for (let i = 0; i < 12; i++) put('rock', 100 + r() * (POND_W - 200), 0.2 + r() * 0.6);
  for (let i = 0; i < 8; i++) put('bush', 60 + r() * (POND_W - 120), 0.15 + r() * 0.5);
  return out;
}
function prop(ctx: CanvasRenderingContext2D, kind: PropKind, x: number, y: number, s: number, seed: number, t: number) {
  const r = rng(seed); ctx.save(); ctx.translate(x, y); ctx.lineWidth = 1.5 * s; ctx.strokeStyle = '#3a2f36'; ctx.lineJoin = 'round';
  const F = (color: string) => { ctx.fillStyle = color; ctx.fill(); ctx.stroke(); };
  switch (kind) {
    case 'tree': { const h = (60 + r() * 30) * s; ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-3 * s, -h * 0.5, 6 * s, h * 0.5); ctx.beginPath(); ctx.ellipse(0, -h * 0.65, (26 + r() * 10) * s, h * 0.38, 0, 0, 6.29); F(`hsl(${95 + r() * 30} 35% ${38 + r() * 12}%)`); break; }
    case 'pine': { const h = (70 + r() * 30) * s; ctx.fillStyle = '#6b4f3a'; ctx.fillRect(-3 * s, -h * 0.3, 6 * s, h * 0.3); for (let k = 0; k < 3; k++) { ctx.beginPath(); ctx.moveTo(0, -h * (0.55 + k * 0.22)); ctx.lineTo(-(22 - k * 5) * s, -h * (0.3 + k * 0.2)); ctx.lineTo((22 - k * 5) * s, -h * (0.3 + k * 0.2)); ctx.closePath(); F('#4f6f4a'); } break; }
    case 'rock': { ctx.beginPath(); ctx.ellipse(0, -6 * s, (10 + r() * 10) * s, (6 + r() * 5) * s, 0, 0, 6.29); F('#a8a2a5'); break; }
    case 'bush': { ctx.beginPath(); ctx.ellipse(0, -10 * s, 18 * s, 11 * s, 0, 0, 6.29); F('#7a9a5e'); ctx.beginPath(); ctx.ellipse(10 * s, -8 * s, 12 * s, 8 * s, 0, 0, 6.29); F('#6f8f55'); break; }
    case 'hut': { ctx.beginPath(); ctx.rect(-30 * s, -44 * s, 60 * s, 44 * s); F('#c9b48a'); ctx.beginPath(); ctx.moveTo(-36 * s, -44 * s); ctx.lineTo(0, -70 * s); ctx.lineTo(36 * s, -44 * s); ctx.closePath(); F('#8b5a3a'); ctx.beginPath(); ctx.rect(-8 * s, -24 * s, 16 * s, 24 * s); F('#5b4f56'); ctx.fillStyle = '#1b0c15'; ctx.font = `${8 * s}px ui-monospace`; ctx.textAlign = 'center'; ctx.fillText('BAIT', 0, -30 * s); break; }
    case 'boat': { ctx.beginPath(); ctx.moveTo(-34 * s, -10 * s); ctx.lineTo(34 * s, -10 * s); ctx.lineTo(24 * s, 4 * s); ctx.lineTo(-24 * s, 4 * s); ctx.closePath(); F('#a06a4a'); ctx.beginPath(); ctx.moveTo(-10 * s, -10 * s); ctx.lineTo(-10 * s, -40 * s); ctx.stroke(); break; }
    case 'pipe': { ctx.beginPath(); ctx.rect(-36 * s, -52 * s, 72 * s, 52 * s); F('#8a8087'); ctx.beginPath(); ctx.arc(0, -22 * s, 16 * s, 0, 6.29); F('#2b2b2b'); ctx.fillStyle = 'rgba(120,150,160,0.6)'; ctx.fillRect(-4 * s, -8 * s, 8 * s, 10 * s + Math.sin(t * 3) * 2 * s); break; }
    case 'pier': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-60 * s, -6 * s, 120 * s, 8 * s); for (let k = 0; k < 4; k++) ctx.fillRect((-50 + k * 33) * s, 0, 5 * s, 26 * s); break; }
    case 'tent': { ctx.beginPath(); ctx.moveTo(-34 * s, 0); ctx.lineTo(0, -46 * s); ctx.lineTo(34 * s, 0); ctx.closePath(); F('#c96a4a'); ctx.beginPath(); ctx.moveTo(-10 * s, 0); ctx.lineTo(0, -20 * s); ctx.lineTo(10 * s, 0); ctx.closePath(); F('#5b4f56'); break; }
    case 'snowman': { ctx.beginPath(); ctx.arc(0, -12 * s, 14 * s, 0, 6.29); F('#ffffff'); ctx.beginPath(); ctx.arc(0, -34 * s, 10 * s, 0, 6.29); F('#ffffff'); ctx.fillStyle = '#1b0c15'; ctx.beginPath(); ctx.arc(-3 * s, -36 * s, 1.2 * s, 0, 6.29); ctx.arc(3 * s, -36 * s, 1.2 * s, 0, 6.29); ctx.fill(); ctx.strokeStyle = '#e08a3a'; ctx.beginPath(); ctx.moveTo(0, -33 * s); ctx.lineTo(9 * s, -31 * s); ctx.stroke(); break; }
    case 'sign': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-2 * s, -34 * s, 4 * s, 34 * s); ctx.beginPath(); ctx.rect(-16 * s, -46 * s, 32 * s, 14 * s); F('#e6d3a5'); break; }
    case 'reed': { ctx.strokeStyle = '#6b8f5a'; ctx.lineWidth = 2 * s; for (let k = 0; k < 3; k++) { ctx.beginPath(); ctx.moveTo((k - 1) * 5 * s, 0); ctx.quadraticCurveTo((k - 1) * 7 * s + Math.sin(t + seed + k) * 4 * s, -20 * s, (k - 1) * 4 * s + Math.sin(t * 1.3 + k) * 5 * s, (-34 - k * 6) * s); ctx.stroke(); } ctx.fillStyle = '#6b4f3a'; ctx.beginPath(); ctx.ellipse(Math.sin(t * 1.3) * 5 * s, -40 * s, 2.5 * s, 7 * s, 0, 0, 6.29); ctx.fill(); break; }
    case 'stump': { ctx.beginPath(); ctx.rect(-10 * s, -14 * s, 20 * s, 14 * s); F('#8b6b4a'); ctx.beginPath(); ctx.ellipse(0, -14 * s, 10 * s, 4 * s, 0, 0, 6.29); F('#c9b48a'); break; }
    case 'lamp': { ctx.fillStyle = '#3a2f36'; ctx.fillRect(-1.5 * s, -60 * s, 3 * s, 60 * s); ctx.beginPath(); ctx.rect(-6 * s, -70 * s, 12 * s, 12 * s); F('#f2e7a8'); break; }
    case 'bench': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-20 * s, -14 * s, 40 * s, 4 * s); ctx.fillRect(-20 * s, -24 * s, 40 * s, 3 * s); ctx.fillRect(-16 * s, -10 * s, 3 * s, 10 * s); ctx.fillRect(13 * s, -10 * s, 3 * s, 10 * s); break; }
  }
  ctx.restore();
}
function name(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) { ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(text, x, y); }
function CardGlyph({ item, seed }: { item: Item; seed: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => { const c = ref.current!; c.width = 320; c.height = 200; const ctx = c.getContext('2d')!; ctx.clearRect(0, 0, 320, 200); drawGlyph(ctx, item.glyph, 160, 100, 150, seed, '#1b0c15', item.key); }, [item, seed]);
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
void depthS;
