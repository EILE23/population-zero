'use client';
import { useEffect, useRef, useState } from 'react';
import { figure, figureColor, hash, jobOf, rng, type FigPose } from '@/features/games/engine';
import type { GameProps } from '../registry';

/**
 * Stick Volley — 2:2 배구(운영자: 2:2 가 낫다). 졸라맨이 공의 낙하점으로 달려가 진짜로 받아 올리고(범프·세트), 세 번째 터치로 네트를 넘긴다(스파이크).
 * 물리: 공은 화면 y 로 떨어진다(중력 GRAV). 치는 쪽은 목표 지점을 정하고 그곳에 떨어지도록 (vx, vy) 를 풀어서 넘긴다 — 네트 위를 못 넘으면 더 높은 궤적으로.
 * 사람은 A 팀 앞사람(색은 내 색). 나머지는 주민. 로그아웃이면 주민끼리 친다. 랠리·3터치·서브·15점 세트.
 */
const W = 960, H = 470, GROUND = 392, NET_X = 480, NET_TOP = 286, GRAV = 1400, BALL_R = 9;
const REACH_X = 34, REACH_Y = 84, JUMP_V = 520, GZ = 1900, SPEED_AI = 265, SPEED_ME = 280, FS = 1.1, CHARGE = 0.7, READ_ERR = 46;
type Side = 'A' | 'B';
interface P { side: Side; x: number; home: number; z: number; vz: number; face: 1 | -1; pose: FigPose; hit: number; name: string; color: string; seed: number; charge: number; err: number }
interface Ball { x: number; y: number; vx: number; vy: number; live: boolean; side: Side; touches: number; last: P | null; serveAt: number; server: Side }

const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));
const other = (s: Side): Side => (s === 'A' ? 'B' : 'A');
/** 목표 (tx, GROUND) 에 T 초 뒤 닿는 속도. 네트를 못 넘으면 T 를 늘려 궤적을 높인다 */
function aim(x: number, y: number, tx: number, T: number, cross: boolean): { vx: number; vy: number } {
  for (let k = 0; k < 6; k++) {
    const vx = (tx - x) / T, vy = (GROUND - BALL_R - y) / T - GRAV * T / 2;
    if (!cross) return { vx, vy };
    const tn = (NET_X - x) / vx; const yn = y + vy * tn + GRAV * tn * tn / 2;
    if (tn > 0 && yn < NET_TOP - 24) return { vx, vy };
    T += 0.14;
  }
  return { vx: (tx - x) / T, vy: (GROUND - BALL_R - y) / T - GRAV * T / 2 };
}
/** 공이 땅에 닿을 x (지금 속도로) */
function landing(b: Ball): number {
  const a = GRAV / 2, bb = b.vy, c = b.y - (GROUND - BALL_R);
  const disc = bb * bb - 4 * a * c; if (disc < 0) return b.x;
  const t = (-bb + Math.sqrt(disc)) / (2 * a); return clamp(b.x + b.vx * Math.max(0, t), 20, W - 20);
}

export default function Game({ me, residents }: GameProps) {
  const [viewport, setViewport] = useState({ touch: false, compactLandscape: false });
  const canvas = useRef<HTMLCanvasElement>(null);
  const input = useRef({ left: false, right: false, jump: false, hit: false });
  const [score, setScore] = useState({ A: 0, B: 0, msg: 'Serve.' });
  const spectator = !me;

  useEffect(() => {
    const update = () => {
      const touch = matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 0;
      const landscape = matchMedia('(orientation: landscape)').matches;
      const h = window.visualViewport?.height ?? window.innerHeight;
      setViewport({ touch, compactLandscape: touch && landscape && h < 560 });
    };
    update();
    window.addEventListener('resize', update);
    window.visualViewport?.addEventListener('resize', update);
    return () => { window.removeEventListener('resize', update); window.visualViewport?.removeEventListener('resize', update); };
  }, []);


  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    const r = rng(hash(`volley:${me?.id ?? 0}:${new Date().toISOString().slice(0, 10)}`));
    const pool = residents.filter((x) => x.id > 0).sort(() => r() - 0.5).slice(0, 4);
    const mk = (side: Side, i: number, home: number, who?: { id: number; handle: string }): P => ({ side, x: home, home, z: 0, vz: 0, face: side === 'A' ? 1 : -1, pose: 'stand', hit: 0, charge: 0, err: 0, name: who?.handle ?? me?.handle ?? 'you', color: who ? '#3a2f36' : figureColor(me?.id ?? 1), seed: hash(who?.handle ?? 'me') });
    const homesA = [380, 170], homesB = [580, 790]; // 앞·뒤 한 명씩
    const ps: P[] = [
      ...homesA.map((h, i) => mk('A', i, h, spectator || i > 0 ? pool[i] : undefined)),
      ...homesB.map((h, i) => mk('B', i, h, pool[2 + i])),
    ];
    const mine = spectator ? null : ps[0];
    const ball: Ball = { x: 170, y: GROUND - 60, vx: 0, vy: 0, live: false, side: 'A', touches: 0, last: null, serveAt: performance.now() + 1200, server: 'A' };
    const sc = { A: 0, B: 0 }; let msg = 'Serve.'; let msgUntil = 0; let raf = 0, last = performance.now();
    const say = (m: string, ms = 1600) => { msg = m; msgUntil = performance.now() + ms; setScore({ ...sc, msg }); };
    const serve = () => {
      const s = ps.find((p) => p.side === ball.server && p.home === (ball.server === 'A' ? 170 : 790))!; // 뒷사람이 서브
      ball.x = s.x; ball.y = GROUND - 70; ball.live = true; ball.side = ball.server; ball.touches = 1; ball.last = s;
      const tx = ball.server === 'A' ? 600 + r() * 280 : 80 + r() * 280;
      const v = aim(ball.x, ball.y, tx, 1.1, true); ball.vx = v.vx; ball.vy = v.vy; s.pose = 'throw'; s.hit = 0.3; s.charge = 0;
      for (const q of ps) if (q.side !== ball.server) q.err = (r() - 0.5) * 2 * READ_ERR; // 받는 쪽이 서브를 읽는 오차 — 완벽한 수비는 랠리가 끝나지 않는다
    };
    const point = (to: Side, why: string) => {
      sc[to]++; ball.live = false; ball.server = to; ball.serveAt = performance.now() + 1500; say(`${why} Point ${to}. ${sc.A}–${sc.B}`, 1500);
      if (sc.A >= 15 || sc.B >= 15) { say(`${sc.A >= 15 ? 'A' : 'B'} takes the set ${sc.A}–${sc.B}.`, 3000); sc.A = 0; sc.B = 0; ball.serveAt = performance.now() + 3200; }
    };
    /** 치기 — 이 쪽의 몇 번째 터치인지에 따라 세트(같은 편 네트 앞)나 넘기기(상대 코트 빈 곳) */
    const strike = (p: P) => {
      const side = p.side; const n = ball.side === side ? ball.touches : 0;
      ball.side = side; ball.touches = n + 1; ball.last = p; p.hit = 0.3;
      for (const q of ps) if (q.side !== side) q.err = (r() - 0.5) * 2 * READ_ERR; // 상대가 이 터치를 새로 읽는다
      const spike = ball.touches >= 3 || p.z > 20;
      if (spike) {
        // 빈 곳을 노린다 — 후보 세 곳 중 상대 선수들에게서 가장 먼 곳
        const opp = ps.filter((q) => q.side !== side);
        const cands = [0, 1, 2].map(() => (side === 'A' ? NET_X + 60 + r() * 380 : 60 + r() * 380));
        const tx = cands.sort((a, b) => Math.min(...opp.map((q) => Math.abs(q.x - b))) - Math.min(...opp.map((q) => Math.abs(q.x - a))))[0];
        const v = aim(ball.x, ball.y, tx, p.z > 20 ? 0.55 : 0.9, true); ball.vx = v.vx; ball.vy = v.vy; p.pose = p.z > 20 ? 'throw' : 'punch';
      } else {
        // 범프·세트: 같은 편에서 네트에 가장 가까운 다른 사람에게 높게
        const mate = ps.filter((q) => q.side === side && q !== p).sort((a, b) => Math.abs(a.x - NET_X) - Math.abs(b.x - NET_X))[0];
        const tx = clamp((mate?.x ?? p.x) + (side === 'A' ? -10 : 10), 30, W - 30);
        const v = aim(ball.x, ball.y, tx, 1.0 + r() * 0.2, false); ball.vx = v.vx; ball.vy = v.vy; p.pose = ball.touches === 1 ? 'charge' : 'jump';
      }
    };
    /** 사람의 타격 — 놓는 순간의 힘(0~1). 약하면 앞으로 짧게 띄우고(세터에게), 세면 상대 코트 깊숙이·낮게 */
    const strikeMe = (p: P, pw: number) => {
      const side = p.side; const n = ball.side === side ? ball.touches : 0;
      ball.side = side; ball.touches = n + 1; ball.last = p; p.hit = 0.3;
      for (const q of ps) if (q.side !== side) q.err = (r() - 0.5) * 2 * READ_ERR;
      const tx = clamp(p.x + p.face * (70 + pw * 640), 30, W - 30); const cross = (tx < NET_X) !== (p.x < NET_X);
      const T = p.z > 20 ? 0.45 + (1 - pw) * 0.4 : 0.6 + (1 - pw) * 0.6;
      const v = aim(ball.x, ball.y, tx, T, cross); ball.vx = v.vx; ball.vy = v.vy;
      p.pose = p.z > 20 ? 'throw' : pw > 0.55 ? 'punch' : 'charge';
    };
    const canReach = (p: P) => Math.abs(p.x - ball.x) < REACH_X + (p.hit > 0 ? -99 : 0) && ball.y > GROUND - p.z - REACH_Y - 30 && ball.y < GROUND - p.z + 4;

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.05, (now - last) / 1000); last = now; const t = now / 1000;
      if (!ball.live && now > ball.serveAt) serve();
      // 공
      if (ball.live) {
        ball.vy += GRAV * dt; ball.x += ball.vx * dt; ball.y += ball.vy * dt;
        // 네트에 걸림
        if (Math.abs(ball.x - NET_X) < 6 && ball.y > NET_TOP - BALL_R) { ball.vx = -ball.vx * 0.4; ball.x += ball.vx > 0 ? 8 : -8; }
        if (ball.x <= 20 || ball.x >= W - 20) ball.vx = -ball.vx * 0.6;
        if (ball.y >= GROUND - BALL_R) { const on = ball.x < NET_X ? 'A' : 'B'; point(other(on), on === 'A' ? 'Ball down on A.' : 'Ball down on B.'); }
        else if (ball.touches > 3) point(other(ball.side), 'Four touches.');
      }
      const land = ball.live ? landing(ball) : NET_X;
      const landSide: Side = land < NET_X ? 'A' : 'B';
      // 사람들
      for (const p of ps) {
        if (p.hit > 0) p.hit -= dt;
        const isMe = p === mine;
        let dx = 0;
        if (isMe) {
          dx = (input.current.right ? 1 : 0) - (input.current.left ? 1 : 0); if (input.current.jump && p.z === 0) p.vz = JUMP_V;
          if (input.current.hit) { p.charge = Math.min(CHARGE, p.charge + dt); dx *= 0.5; if (p.hit <= 0 && p.z === 0) p.pose = 'charge'; }
          else if (p.charge > 0) { const pw = p.charge / CHARGE; p.charge = 0; if (ball.live && canReach(p) && ball.last !== p) strikeMe(p, pw); else { p.pose = 'punch'; p.hit = 0.25; } } // 놓는 순간 공이 닿아 있어야 맞는다 — 타이밍이 실력
        }
        else if (ball.live && ball.side !== other(p.side) || ball.live && landSide === p.side) {
          // 공이 우리 코트로 오면 낙하점에 가장 가까운 사람이 받으러 간다. 나머지는 자기 자리로
          const mates = ps.filter((q) => q.side === p.side && q !== ball.last);
          // 사람이 낙하점 가까이(140px) 있으면 그 공은 사람 몫 — 팀원이 대신 받아 주지 않는다
          const humanHas = mine && mine.side === p.side && mine !== ball.last && Math.abs(mine.x - land) < 140;
          const taker = humanHas ? mine : mates.filter((q) => q !== mine).sort((a, b) => Math.abs(a.x - land) - Math.abs(b.x - land))[0] ?? p;
          const target = p === taker && landSide === p.side ? land + p.err + (p.side === 'A' ? -12 : 12) : p.home;
          dx = Math.abs(target - p.x) > 6 ? Math.sign(target - p.x) : 0;
          if (p === taker && landSide === p.side && ball.y < GROUND - 120 && Math.abs(ball.x - p.x) < 40 && Math.abs(p.x - NET_X) < 160 && p.z === 0 && ball.touches >= 2) p.vz = JUMP_V; // 스파이크 점프
        } else { const target = p.home; dx = Math.abs(target - p.x) > 6 ? Math.sign(target - p.x) : 0; }
        const lo = p.side === 'A' ? 30 : NET_X + 24, hi = p.side === 'A' ? NET_X - 24 : W - 30;
        p.x = clamp(p.x + dx * (isMe ? SPEED_ME : SPEED_AI) * dt, lo, hi);
        if (dx) p.face = dx as 1 | -1; else p.face = p.side === 'A' ? 1 : -1;
        if (p.z > 0 || p.vz > 0) { p.vz -= GZ * dt; p.z = Math.max(0, p.z + p.vz * dt); if (p.z === 0) p.vz = 0; }
        if (p.hit <= 0 && !(isMe && p.charge > 0 && p.z === 0)) p.pose = p.z > 0 ? 'jump' : dx ? 'run' : 'stand';
        // 치기 판정
        if (ball.live && canReach(p) && ball.last !== p) {
          if (isMe) { /* 사람은 놓는 순간에 친다(위) */ }
          else if (ball.side !== p.side || ball.touches < 3) strike(p);
        }
      }
      // 그림
      const s = c.width / W; ctx.setTransform(s, 0, 0, s, 0, 0);
      ctx.fillStyle = '#eef0f2'; ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = '#e6d9b8'; ctx.fillRect(0, GROUND - 6, W, H - GROUND + 6);
      ctx.strokeStyle = '#8f8489'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(0, GROUND); ctx.lineTo(W, GROUND); ctx.stroke();
      ctx.fillStyle = '#8f8489'; ctx.fillRect(NET_X - 2, NET_TOP, 4, GROUND - NET_TOP); ctx.fillStyle = '#e8c96a'; ctx.fillRect(NET_X - 30, NET_TOP, 60, 4);
      ctx.strokeStyle = 'rgba(0,0,0,0.12)'; ctx.lineWidth = 1; ctx.beginPath(); for (let y = NET_TOP + 8; y < GROUND; y += 8) { ctx.moveTo(NET_X - 30, y); ctx.lineTo(NET_X + 30, y); } for (let x = NET_X - 30; x <= NET_X + 30; x += 8) { ctx.moveTo(x, NET_TOP + 4); ctx.lineTo(x, GROUND); } ctx.stroke();
      if (ball.live) { ctx.fillStyle = 'rgba(0,0,0,0.12)'; ctx.beginPath(); ctx.ellipse(land, GROUND, 10, 3, 0, 0, 6.29); ctx.fill(); }
      for (const p of [...ps].sort((a, b) => a.x - b.x)) {
        const fy = GROUND - p.z;
        if (p.z > 0) { ctx.fillStyle = 'rgba(0,0,0,0.15)'; ctx.beginPath(); ctx.ellipse(p.x, GROUND, 12, 4, 0, 0, 6.29); ctx.fill(); }
        figure(ctx, p.x, fy, FS, p.pose, p.face, p.color, t + p.seed % 5, false);
        if (p === mine && p.charge > 0) { ctx.fillStyle = '#e6e0da'; ctx.fillRect(p.x - 20, fy - 76, 40, 5); ctx.fillStyle = p.charge >= CHARGE ? '#ad7096' : '#3a2f36'; ctx.fillRect(p.x - 20, fy - 76, 40 * (p.charge / CHARGE), 5); }
        ctx.fillStyle = '#5b4f56'; ctx.font = 'bold 10.5px ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillText(p === mine ? p.name : `${p.name} · ${jobOf(p.name).name}`, p.x, fy - 62);
      }
      ctx.fillStyle = '#ffffff'; ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.arc(ball.live ? ball.x : ps.find((p) => p.side === ball.server && p.home === (ball.server === 'A' ? 170 : 790))!.x + 14, ball.live ? ball.y : GROUND - 44, BALL_R, 0, 6.29); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#1b0c15'; ctx.font = 'bold 22px ui-monospace, monospace'; ctx.textAlign = 'center'; ctx.fillText(`${sc.A}   ${sc.B}`, NET_X, 40);
      ctx.font = 'bold 11px ui-monospace, monospace'; ctx.fillStyle = '#5b4f56'; ctx.fillText('A', NET_X - 60, 40); ctx.fillText('B', NET_X + 60, 40);
      if (now < msgUntil) { ctx.font = 'bold 13px system-ui, sans-serif'; ctx.fillStyle = '#7b526c'; ctx.fillText(msg, NET_X, 66); }
      if (ball.live && ball.touches > 0) { ctx.font = '10.5px ui-monospace, monospace'; ctx.fillStyle = '#5b4f56'; ctx.fillText(`${ball.side} · touch ${ball.touches}`, NET_X, 86); }
    };
    raf = requestAnimationFrame(frame);
    const host = c.parentElement ?? c;
    const fit = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
      const maxWidth = Math.min(W, host.clientWidth || W);
      const viewportHeight = window.visualViewport?.height ?? window.innerHeight;
      const heightBudget = viewport.compactLandscape ? Math.max(220, viewportHeight - 24) : Number.POSITIVE_INFINITY;
      const width = Math.max(240, Math.min(maxWidth, heightBudget * (W / H)));
      const height = width * (H / W);
      c.width = Math.round(width * dpr); c.height = Math.round(height * dpr);
      c.style.width = `${width}px`; c.style.height = `${height}px`;
    };
    fit(); const ro = new ResizeObserver(fit); ro.observe(host); window.visualViewport?.addEventListener('resize', fit);
    const set = (k: string, v: boolean, e: KeyboardEvent) => { const i = input.current; if (k === 'ArrowLeft') i.left = v; else if (k === 'ArrowRight') i.right = v; else if (k === ' ') i.jump = v; else if (k === 'x' || k === 'X' || k === 'ArrowUp') i.hit = v; else return; e.preventDefault(); };
    const kd = (e: KeyboardEvent) => set(e.key, true, e), ku = (e: KeyboardEvent) => set(e.key, false, e);
    if (!spectator) { window.addEventListener('keydown', kd); window.addEventListener('keyup', ku); }
    return () => { cancelAnimationFrame(raf); ro.disconnect(); window.visualViewport?.removeEventListener('resize', fit); window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, [me, residents, spectator, viewport.compactLandscape]);

  const hold = (k: keyof typeof input.current) => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });
  return (
    <div className={viewport.compactLandscape ? "mx-auto w-full max-w-none" : "mx-auto w-full max-w-[960px]"} style={viewport.compactLandscape ? { paddingLeft: "max(8px, env(safe-area-inset-left))", paddingRight: "max(8px, env(safe-area-inset-right))" } : undefined}>
      <div className="flex items-center justify-between font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft"><span>Stick Volley · 2 v 2 · first to 15</span><span>{score.A}–{score.B}</span></div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#eef0f2]">
        <canvas ref={canvas} className="block w-full touch-none" />
        {spectator && <div className="absolute inset-x-0 bottom-0 bg-paper/90 px-3 py-2 text-[12.5px]">The residents are playing. Log in to take the front spot on team A.</div>}
        {!spectator && viewport.touch && (
          <div className="absolute inset-x-0 bottom-0 flex items-end justify-between p-2">
            <div className="flex gap-1"><button {...hold('left')} className="size-12 rounded-full bg-ink/70 text-paper">←</button><button {...hold('right')} className="size-12 rounded-full bg-ink/70 text-paper">→</button></div>
            <div className="flex gap-2"><button {...hold('jump')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Jump</button><button {...hold('hit')} className="size-12 rounded-full bg-accent text-[11px] font-bold text-paper">Hit</button></div>
          </div>
        )}
      </div>
      {/* 도움말은 화면에 있는 조작으로 — 휴대폰엔 X 키가 없다 */}
      {!spectator && !viewport.touch && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">← → move · SPACE jump · hold X, release to hit</p>}
      {!spectator && viewport.touch && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">Hold Hit to charge. Release when the ball is within reach.</p>}
    </div>
  );
}
