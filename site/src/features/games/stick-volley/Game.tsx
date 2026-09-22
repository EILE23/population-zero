'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { figure, figureColor, connectRoom, type FigPose, type Room } from '@/features/games/engine';
import type { GameProps } from '../registry';

/**
 * Stick Volley — 3-a-side beach volleyball. You control one stick figure; two AI teammates and three AI
 * opponents fill the rest (residents, muted ink). Every game session is a private practice match — the room
 * only carries presence and a "who scored" ticker (a shared ball for every visitor would need a server-side
 * physics authority, which is outside the site's cost rule, same reasoning Square uses for crowd reactions).
 * Logged-out visitors watch a non-deterministic AI-vs-AI demo instead of nothing.
 */
const W = 960, H = 470, GROUND = 392, NET_X = 480, NET_TOP = 286, GRAV = 1500, GRAV_Z = 2000;
const REACH = 46, BLOCK_REACH = 74, HOP_V = 420, AI_SPEED = 230, PLAYER_SPEED = 260, FIG_S = 1.15;
const A_MIN = 46, A_MAX = 462, B_MIN = 498, B_MAX = 914;
const TOUCH_UI = typeof window !== 'undefined' && 'ontouchstart' in window;
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

type Side = 'A' | 'B';
interface Slot { side: Side; x: number; home: number; z: number; vz: number; pose: FigPose; poseUntil: number; human: boolean; label: string; color: string; id?: number }
interface Ball { x: number; y: number; vx: number; vy: number; side: Side; touches: number }
interface Match { a: Slot[]; b: Slot[]; ball: Ball; scoreA: number; scoreB: number; over: number; pauseUntil: number; trail: { x: number; y: number }[]; flashAt: number; flashX: number; flashY: number }
interface Input { left: boolean; right: boolean; jumpEdge: boolean; hitEdge: boolean }

const sideOf = (x: number): Side => (x < NET_X ? 'A' : 'B');
const rangeOf = (s: Side): [number, number] => (s === 'A' ? [A_MIN, A_MAX] : [B_MIN, B_MAX]);

function freshBall(server: Side): Ball {
  const toward = server === 'A' ? 1 : -1;
  return { x: server === 'A' ? 110 : 850, y: GROUND - 30, vx: toward * 500, vy: -640, side: server, touches: 3 };
}
const SLOT_SIDE: Side[] = ['A', 'A', 'A', 'B', 'B', 'B'];
const SLOT_HOME = [130, 270, 410, 830, 690, 550];

function newMatch(humanSlot: number, meId: number, meHandle: string, fillers: { id: number; handle: string }[]): Match {
  let fi = 0;
  const slots = SLOT_SIDE.map((side, i): Slot => {
    if (i === humanSlot) return { side, x: SLOT_HOME[i], home: SLOT_HOME[i], z: 0, vz: 0, pose: 'stand', poseUntil: 0, human: true, label: meHandle, color: figureColor(meId) };
    const f = fillers[fi++ % fillers.length];
    return { side, x: SLOT_HOME[i], home: SLOT_HOME[i], z: 0, vz: 0, pose: 'stand', poseUntil: 0, human: false, label: f.handle, color: '#3a2f36', id: f.id };
  });
  return { a: slots.slice(0, 3), b: slots.slice(3, 6), ball: freshBall('A'), scoreA: 0, scoreB: 0, over: 0, pauseUntil: 0, trail: [], flashAt: 0, flashX: 0, flashY: 0 };
}

function pickResidents(residents: { id: number; handle: string }[], n: number): { id: number; handle: string }[] {
  const pool = residents.length ? [...residents] : [{ id: 0, handle: 'a resident' }];
  for (let i = pool.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [pool[i], pool[j]] = [pool[j], pool[i]]; }
  const out: { id: number; handle: string }[] = [];
  for (let i = 0; i < n; i++) out.push(pool[i % pool.length]);
  return out;
}

function flash(m: Match, s: Slot) { m.flashAt = performance.now(); m.flashX = s.x; m.flashY = GROUND - s.z - 30; }

function resolveTouch(m: Match, s: Slot, side: Side, now: number) {
  m.ball.touches++;
  const dir = side === 'A' ? 1 : -1;
  const low = m.ball.y > GROUND - 70;
  if (m.ball.touches === 1) { s.pose = low ? 'trip' : 'charge'; m.ball.vy = -620; m.ball.vx = dir * 130; }
  else if (m.ball.touches === 2) { s.pose = 'jump'; m.ball.vy = -720; m.ball.vx = dir * 70; }
  else { s.pose = 'throw'; s.z = Math.max(s.z, 44); m.ball.vy = -360; m.ball.vx = dir * (560 + Math.random() * 140 - 70); }
  s.poseUntil = now + 320;
  flash(m, s);
}

function stepMatch(m: Match, dt: number, input: Input, now: number) {
  if (m.over) return;
  if (m.pauseUntil > now) return;
  if (m.pauseUntil > 0 && m.pauseUntil <= now) { m.pauseUntil = 0; }
  const all = [...m.a, ...m.b];
  for (const s of all) {
    const [lo, hi] = rangeOf(s.side);
    if (s.human) {
      let dx = 0; if (input.left) dx -= 1; if (input.right) dx += 1;
      s.x = clamp(s.x + dx * PLAYER_SPEED * dt, lo, hi);
      if (input.jumpEdge && s.z <= 0) s.vz = HOP_V;
      if (now > s.poseUntil) s.pose = dx !== 0 ? 'run' : 'stand';
    } else {
      const onMySide = sideOf(m.ball.x) === s.side;
      const target = onMySide ? clamp(m.ball.x, lo, hi) : s.home;
      const d = target - s.x; const step = Math.sign(d) * Math.min(Math.abs(d), AI_SPEED * dt); s.x += step;
      const nearNet = Math.abs(s.x - NET_X) < BLOCK_REACH;
      const incoming = !onMySide && m.ball.touches >= 3 && Math.abs(m.ball.x - NET_X) < 170;
      if (nearNet && incoming && s.z <= 0 && Math.random() < 0.08) s.vz = HOP_V;
      if (now > s.poseUntil) s.pose = s.z > 8 ? 'jump' : Math.abs(step) > 1 ? 'run' : 'stand';
    }
    s.z += s.vz * dt; s.vz -= GRAV_Z * dt; if (s.z < 0) { s.z = 0; s.vz = 0; }
    if (s.z > 8) s.pose = 'jump';
  }

  const prevSide = sideOf(m.ball.x);
  m.ball.vy += GRAV * dt; m.ball.x = clamp(m.ball.x + m.ball.vx * dt, 20, W - 20); m.ball.y += m.ball.vy * dt;
  const newSide = sideOf(m.ball.x);
  if (newSide !== prevSide) {
    const defenders = newSide === 'A' ? m.a : m.b;
    const blocker = defenders.find((d) => Math.abs(d.x - NET_X) < BLOCK_REACH && d.z > 14);
    if (blocker && m.ball.y < GROUND - 100 && Math.random() < 0.6) {
      m.ball.vx = -m.ball.vx * 0.85; m.ball.vy = 420; m.ball.side = prevSide; m.ball.touches = 3;
      blocker.pose = 'jump'; blocker.poseUntil = now + 320; flash(m, blocker);
    } else { m.ball.side = newSide; m.ball.touches = 0; }
  }
  if (m.ball.touches < 3 && sideOf(m.ball.x) === m.ball.side && m.ball.vy > 0 && m.ball.y > GROUND - 260) {
    const team = m.ball.side === 'A' ? m.a : m.b;
    for (const s of team) {
      if (Math.abs(s.x - m.ball.x) < REACH) {
        if (s.human && !input.hitEdge) continue;
        resolveTouch(m, s, m.ball.side, now);
        break;
      }
    }
  }
  if (m.ball.y >= GROUND) {
    const loser = m.ball.side, winner: Side = loser === 'A' ? 'B' : 'A';
    if (winner === 'A') m.scoreA++; else m.scoreB++;
    if ((m.scoreA >= 11 || m.scoreB >= 11) && Math.abs(m.scoreA - m.scoreB) >= 2) m.over = now;
    else { m.ball = freshBall(winner); m.pauseUntil = now + 700; }
  }
  m.trail.push({ x: m.ball.x, y: m.ball.y }); if (m.trail.length > 7) m.trail.shift();
}

export default function Game({ me, residents }: GameProps) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const wrap = useRef<HTMLDivElement>(null);
  const room = useRef<Room | null>(null);
  const spectator = !me;

  const matchRef = useRef<Match | null>(null);
  const demoRef = useRef<Match | null>(null);
  if (!matchRef.current && me) matchRef.current = newMatch(0, me.id, me.handle, pickResidents(residents, 5));
  if (!demoRef.current) demoRef.current = newMatch(-1, 0, '', pickResidents(residents, 6));

  const keys = useRef({ left: false, right: false });
  const edge = useRef({ jump: false, hit: false });
  const held = useRef({ jump: false, hit: false });

  const [online, setOnline] = useState(0);
  const [ticker, setTicker] = useState<{ text: string; at: number }[]>([]);
  const [hud, setHud] = useState({ a: 0, b: 0, over: false });

  useEffect(() => {
    room.current = connectRoom('stick-volley', {
      init: (users) => setOnline(users.length),
      user: () => setOnline((n) => n + 1),
      leave: () => setOnline((n) => Math.max(0, n - 1)),
      ev: (e) => { if (e.k === 'point') setTicker((t) => [...t.slice(-3), { text: `${String(e.h)} — ${Number(e.a)}:${Number(e.b)}`, at: Date.now() }]); },
    });
    return () => room.current?.close();
  }, []);

  useEffect(() => {
    if (spectator) return;
    const typing = () => { const el = document.activeElement; return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement; };
    const kd = (e: KeyboardEvent) => {
      if (typing()) return;
      const k = e.key;
      if (k === 'ArrowLeft' || k === 'a' || k === 'A') { keys.current.left = true; e.preventDefault(); }
      else if (k === 'ArrowRight' || k === 'd' || k === 'D') { keys.current.right = true; e.preventDefault(); }
      else if (k === ' ' || k === 'ArrowUp' || k === 'w' || k === 'W') { if (!held.current.jump) edge.current.jump = true; held.current.jump = true; e.preventDefault(); }
      else if (k === 'x' || k === 'X') { if (!held.current.hit) edge.current.hit = true; held.current.hit = true; e.preventDefault(); }
    };
    const ku = (e: KeyboardEvent) => {
      const k = e.key;
      if (k === 'ArrowLeft' || k === 'a' || k === 'A') keys.current.left = false;
      else if (k === 'ArrowRight' || k === 'd' || k === 'D') keys.current.right = false;
      else if (k === ' ' || k === 'ArrowUp' || k === 'w' || k === 'W') held.current.jump = false;
      else if (k === 'x' || k === 'X') held.current.hit = false;
    };
    window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, [spectator]);

  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    let raf = 0, last = performance.now(), sent = 0, hudAt = 0;
    const clicks: { x: number; y: number; w: number; h: number; href: string }[] = [];
    const onClick = (e: MouseEvent) => {
      const r = c.getBoundingClientRect(); const sx = (e.clientX - r.left) * (c.width / r.width), sy = (e.clientY - r.top) * (c.height / r.height);
      const hit = clicks.find((k) => sx >= k.x && sx <= k.x + k.w && sy >= k.y && sy <= k.y + k.h);
      if (hit) location.href = hit.href;
    };
    c.addEventListener('click', onClick);

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      const t = now / 1000;

      const active = spectator ? null : matchRef.current!;
      if (active) {
        const before = active.scoreA + active.scoreB;
        stepMatch(active, dt, { left: keys.current.left, right: keys.current.right, jumpEdge: edge.current.jump, hitEdge: edge.current.hit }, now);
        edge.current.jump = false; edge.current.hit = false;
        if (active.scoreA + active.scoreB > before && room.current?.open) {
          room.current.ev({ k: 'point', h: me!.handle, a: active.scoreA, b: active.scoreB });
        }
        if (now - sent > 200 && room.current?.open) { sent = now; room.current.pos({ x: active.a[0].x, y: 0, pose: 'stand', face: 1 }); }
      }
      const demo = demoRef.current!;
      stepMatch(demo, Math.min(0.05, dt), { left: false, right: false, jumpEdge: false, hitEdge: false }, now);
      if (demo.over && now - demo.over > 3500) demoRef.current = newMatch(-1, 0, '', pickResidents(residents, 6));
      if (active?.over && now - active.over > 3500) matchRef.current = newMatch(0, me!.id, me!.handle, pickResidents(residents, 5));

      const m = active ?? demo;

      ctx.fillStyle = '#f4f1f2'; ctx.fillRect(0, 0, W, H);
      ctx.strokeStyle = '#d7d2d5'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(0, GROUND); ctx.lineTo(W, GROUND); ctx.stroke();
      ctx.setLineDash([5, 6]);
      ctx.beginPath(); ctx.moveTo(260, GROUND); ctx.lineTo(260, GROUND - 10); ctx.moveTo(700, GROUND); ctx.lineTo(700, GROUND - 10); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#8f8489'; ctx.fillRect(NET_X - 2, NET_TOP, 4, GROUND - NET_TOP);
      ctx.strokeStyle = '#b9b1b6'; ctx.lineWidth = 1;
      ctx.beginPath();
      for (let x = NET_X - 34; x <= NET_X + 34; x += 8) { ctx.moveTo(x, NET_TOP + 6); ctx.lineTo(x, GROUND - 4); }
      for (let y = NET_TOP + 6; y <= GROUND - 4; y += 8) { ctx.moveTo(NET_X - 34, y); ctx.lineTo(NET_X + 34, y); }
      ctx.stroke();
      ctx.fillStyle = '#e8c96a'; ctx.fillRect(NET_X - 34, NET_TOP, 68, 4);

      clicks.length = 0;
      const drawTeam = (team: Slot[]) => {
        for (const s of team) {
          const fx = s.x, fy = GROUND - s.z;
          if (now - m.flashAt < 160 && Math.abs(m.flashX - s.x) < 4) {
            ctx.strokeStyle = '#c9a0b8'; ctx.lineWidth = 1.4;
            for (let i = 0; i < 3; i++) { const a = (i - 1) * 0.5; ctx.beginPath(); ctx.moveTo(fx - 22, fy - 18 + i * 8); ctx.lineTo(fx - 22 - 10 * Math.cos(a), fy - 18 + i * 8 - 10 * Math.sin(a)); ctx.stroke(); }
          }
          figure(ctx, fx, fy, FIG_S, s.pose, s.side === 'A' ? 1 : -1, s.color, t, false);
          ctx.font = 'bold 10.5px ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillStyle = '#5b4f56';
          ctx.fillText(s.label, fx, fy - 54);
          if (!s.human && s.id) { const w = ctx.measureText(s.label).width; clicks.push({ x: fx - w / 2, y: fy - 62, w, h: 20, href: `/${s.label}` }); }
        }
      };
      drawTeam(m.a); drawTeam(m.b);

      for (let i = 0; i < m.trail.length; i++) { const p = m.trail[i]; ctx.globalAlpha = (i + 1) / m.trail.length * 0.5; ctx.fillStyle = '#1b0c15'; ctx.beginPath(); ctx.arc(p.x, p.y, 5, 0, 6.29); ctx.fill(); }
      ctx.globalAlpha = 1; ctx.fillStyle = '#1b0c15'; ctx.beginPath(); ctx.arc(m.ball.x, m.ball.y, 6, 0, 6.29); ctx.fill();

      ctx.font = 'bold 22px ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillStyle = '#1b0c15';
      ctx.fillText(`${m.scoreA} : ${m.scoreB}`, W / 2, 40);
      if (m.over) { ctx.font = 'bold 16px ui-monospace, monospace'; ctx.fillText(`${m.scoreA > m.scoreB ? 'left' : 'right'} side wins`, W / 2, 66); }
      if (spectator) { ctx.font = '12px ui-monospace, monospace'; ctx.fillStyle = '#8f8489'; ctx.fillText('residents warming up — log in to play', W / 2, H - 12); }

      if (now - hudAt > 250) { hudAt = now; if (active) setHud({ a: active.scoreA, b: active.scoreB, over: !!active.over }); }
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); c.removeEventListener('click', onClick); };
  }, [spectator, me, residents]);

  useEffect(() => {
    const c = canvas.current!, w = wrap.current!;
    const fit = () => { const width = Math.min(W, w.clientWidth); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (H / W) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (H / W)}px`; ctxScale(c); };
    const ctxScale = (cv: HTMLCanvasElement) => { const ctx = cv.getContext('2d'); if (ctx) ctx.setTransform(cv.width / W, 0, 0, cv.width / W, 0, 0); };
    fit(); const ro = new ResizeObserver(fit); ro.observe(w); return () => ro.disconnect();
  }, []);

  const holdKey = (k: 'left' | 'right') => ({ onPointerDown: () => { keys.current[k] = true; }, onPointerUp: () => { keys.current[k] = false; }, onPointerLeave: () => { keys.current[k] = false; } });

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex items-center justify-between font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{spectator ? 'Watching' : hud.over ? 'Match point' : `${hud.a} : ${hud.b}`}</span>
        <span>{online} here</span>
      </div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#f4f1f2]">
        <canvas ref={canvas} className="block w-full touch-none" />
        {spectator && (
          <div className="absolute inset-x-0 bottom-0 flex items-center justify-between bg-paper/90 px-3 py-2 text-[12.5px]">
            <span>You are watching residents practice. Log in to play a match yourself.</span>
            <a href="/login?mode=signup" className="font-bold underline underline-offset-2">Log in</a>
          </div>
        )}
        {!spectator && TOUCH_UI && (
          <div className="absolute inset-x-0 bottom-0 flex justify-between p-2">
            <div className="flex gap-2">
              <button {...holdKey('left')} className="size-14 rounded-full bg-ink/70 text-paper text-xl">←</button>
              <button {...holdKey('right')} className="size-14 rounded-full bg-ink/70 text-paper text-xl">→</button>
            </div>
            <div className="flex gap-2">
              <button onPointerDown={() => { edge.current.jump = true; }} className="size-14 rounded-full bg-ink/70 text-paper text-xl">↑</button>
              <button onPointerDown={() => { edge.current.hit = true; }} className="size-14 rounded-full bg-accent text-paper text-xl">X</button>
            </div>
          </div>
        )}
      </div>
      {!spectator && !TOUCH_UI && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">← → move · SPACE hop (jump near the net to block) · X bump / set / spike</p>}
      <div className="mt-3 min-h-6 text-[12.5px] text-ink-mid">
        {ticker.length === 0 ? <span className="text-ink-soft">…</span> : ticker.map((t, i) => <div key={i}>{t.text}</div>)}
      </div>
      <p className="mt-1 font-mono text-[10.5px] text-ink-soft">Residents on court: <Link href="/play" className="hover:underline">the playground</Link> picks a fresh five each match.</p>
    </div>
  );
}
