'use client';
import { useEffect, useRef, useState } from 'react';
import { figure } from '@/lib/stickman';
import { around, band, BAND_H, collide, figPlats, figureColor, metres, npcAt, npcsOf, platX, poseOf, shoved, step, WORLD_W, type Body, type Figure, type Input, type Npc, type Pose } from '@/lib/tower';

/**
 * Climb — 화면. 물리·지형·NPC 는 lib/tower 가 정하고 여기는 그리고 입력을 받고 서버(DO)와 위치를 주고받는다.
 *
 * 화면에 보이는 것: 발판(성질별 모양), 주민 NPC(층마다 배치, 방해꾼 다수), 다른 사람들(활동 중이면 서 있고 쉬는 중이면 앉아 있음),
 * 나. 클릭하면 그 사람 블로그. 아래엔 성의 없는 채팅 한 줄.
 * 로그인 안 했으면 구경만 한다 — 졸라맨이 없다.
 */
export interface ResidentLite { id: number; handle: string; line: string }
interface Other { uid: number; handle: string; avatar: string; x: number; y: number; tx: number; ty: number; pose: Pose; face: 1 | -1; status: 'active' | 'rest' }
interface Chat { who: string; body: string; at: number }

const VIEW_H = 640;
const TOUCH = typeof window !== 'undefined' && 'ontouchstart' in window;

export function ClimbGame({ residents, me, best }: { residents: ResidentLite[]; me: { id: number; handle: string } | null; best: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const wrap = useRef<HTMLDivElement>(null);
  const ws = useRef<WebSocket | null>(null);
  const body = useRef<Body>({ x: 480, y: 0, vx: 0, vy: 0, on: null, face: 1, idle: 0, hurt: 0, charge: 0, apex: 0 });
  const input = useRef<Input>({ left: false, right: false, jump: false });
  const crumbled = useRef(new Map<string, number>()); // id → 밟은 시각
  const others = useRef(new Map<number, Other>());
  const said = useRef(new Map<number, { body: string; until: number }>()); // 채팅 말풍선 — uid → 말, 4초
  const cam = useRef(0);
  const tour = useRef({ y: 0, manualUntil: 0, uid: 0, until: 0 }); // 구경꾼 카메라: 바닥에서 천천히 올라가며 탑을 훑고, 휠·드래그로 직접 볼 수 있다
  const [chats, setChats] = useState<Chat[]>([]);
  const [line, setLine] = useState('');
  const [hud, setHud] = useState({ h: 0, best, online: 0, resting: 0, connected: false });
  const bestRef = useRef(best);
  const ready = useRef(!me); // 서버가 내 저장된 자리를 줄 때까지 나를 그리지 않는다(새로고침 때 바닥에서 깜빡이지 않게)
  const prevFig = useRef(new Map<string, number>());
  const spectator = !me;

  // ── 서버 ──
  useEffect(() => {
    let alive = true, sock: WebSocket | null = null, retry = 0;
    const connect = () => {
      if (!alive) return;
      const proto = location.protocol === 'https:' ? 'wss' : 'ws';
      sock = new WebSocket(`${proto}://${location.host}/ws/climb`);
      ws.current = sock;
      sock.onopen = () => { retry = 0; setHud((h) => ({ ...h, connected: true })); };
      sock.onmessage = (e) => {
        let m: { t: string; [k: string]: unknown }; try { m = JSON.parse(String(e.data)); } catch { return; }
        const map = others.current;
        const put = (u: Record<string, unknown>) => {
          const uid = Number(u.uid);
          if (me && uid === me.id) { // 내 저장된 자리 — 거기서 다시 시작
            if (m.t === 'init') { body.current = { ...body.current, x: Number(u.x) || 480, y: Number(u.y) || 0, vx: 0, vy: 0, on: null, apex: Number(u.y) || 0 }; cam.current = body.current.y; bestRef.current = Math.max(bestRef.current, Number(u.best) || 0); ready.current = true; }
            return;
          }
          const prev = map.get(uid);
          map.set(uid, { uid, handle: String(u.handle ?? ''), avatar: String(u.avatar ?? ''), x: prev?.x ?? (Number(u.x) || 0), y: prev?.y ?? (Number(u.y) || 0),
            tx: Number(u.x) || 0, ty: Number(u.y) || 0, pose: (u.pose as Pose) ?? 'stand', face: u.face === -1 ? -1 : 1, status: u.status === 'rest' ? 'rest' : 'active' });
        };
        if (m.t === 'init') { map.clear(); for (const u of m.users as Record<string, unknown>[]) put(u); ready.current = true; }
        else if (m.t === 'user') put(m.u as Record<string, unknown>);
        else if (m.t === 'pos') { const o = map.get(Number(m.uid)); if (o) { o.tx = Number(m.x); o.ty = Number(m.y); o.pose = m.pose as Pose; o.face = m.face === -1 ? -1 : 1; o.status = 'active'; } }
        else if (m.t === 'rest') { const o = map.get(Number(m.uid)); if (o) { o.status = 'rest'; o.pose = 'sit'; } }
        else if (m.t === 'leave') map.delete(Number(m.uid));
        else if (m.t === 'chat') { setChats((c) => [...c.slice(-7), { who: String(m.handle), body: String(m.body), at: Date.now() }]); if (Number(m.uid)) said.current.set(Number(m.uid), { body: String(m.body), until: performance.now() + 4000 }); }
      };
      sock.onclose = () => { setHud((h) => ({ ...h, connected: false })); if (alive) setTimeout(connect, Math.min(15000, 1000 * 2 ** retry++)); };
    };
    connect();
    return () => { alive = false; sock?.close(); };
  }, [me]);

  // ── 입력 ──
  useEffect(() => {
    if (spectator) return;
    const typing = () => { const el = document.activeElement; return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement; };
    const key = (down: boolean) => (e: KeyboardEvent) => {
      if (typing()) return;
      const k = e.key;
      if (k === 'ArrowLeft' || k === 'a' || k === 'A') { input.current.left = down; e.preventDefault(); }
      else if (k === 'ArrowRight' || k === 'd' || k === 'D') { input.current.right = down; e.preventDefault(); }
      else if (k === ' ' || k === 'ArrowUp' || k === 'w' || k === 'W') { input.current.jump = down; e.preventDefault(); } // 누르는 동안 힘을 모으고 놓으면 뛴다
    };
    const kd = key(true), ku = key(false);
    window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, [spectator]);

  // ── 루프 ──
  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    let raf = 0, last = performance.now(), acc = 0, sent = 0, hudAt = 0;
    const DT = 1 / 120;
    // 주민 NPC 캐시(층별)
    const npcCache = new Map<number, Npc[]>();
    const npcs = (n: number) => { let v = npcCache.get(n); if (!v) { v = npcsOf(n, residents.length); npcCache.set(n, v); } return v; };
    const clicks: { x: number; y: number; w: number; h: number; href: string }[] = [];
    const onClick = (e: MouseEvent) => {
      const r = c.getBoundingClientRect(); const sx = (e.clientX - r.left) * (c.width / r.width), sy = (e.clientY - r.top) * (c.height / r.height);
      const hit = clicks.find((k) => sx >= k.x && sx <= k.x + k.w && sy >= k.y && sy <= k.y + k.h);
      if (hit) location.href = hit.href;
    };
    c.addEventListener('click', onClick);
    // 구경꾼: 휠·드래그로 탑을 훑는다
    const onWheel = (e: WheelEvent) => { if (!spectator) return; e.preventDefault(); tour.current.y = Math.max(0, tour.current.y - e.deltaY * 1.5); tour.current.manualUntil = performance.now() + 8000; };
    let dragY: number | null = null;
    const onPD = (e: PointerEvent) => { if (spectator) dragY = e.clientY; };
    const onPM = (e: PointerEvent) => { if (dragY === null) return; tour.current.y = Math.max(0, tour.current.y + (e.clientY - dragY) * 1.5); dragY = e.clientY; tour.current.manualUntil = performance.now() + 8000; };
    const onPU = () => { dragY = null; };
    c.addEventListener('wheel', onWheel, { passive: false }); c.addEventListener('pointerdown', onPD); c.addEventListener('pointermove', onPM); c.addEventListener('pointerup', onPU); c.addEventListener('pointerleave', onPU);

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.1, (now - last) / 1000); last = now; acc += dt;
      const t = Date.now() / 1000;
      // 물리 (고정 틱)
      if (!spectator && ready.current) {
        // 근처 졸라맨들(주민 NPC + 다른 사람) — 머리 위는 발판, 옆은 벽
        const near: Figure[] = [];
        const by = body.current.y; const nb = Math.floor(by / BAND_H);
        for (const n of [nb - 1, nb, nb + 1]) if (n >= 0) for (const npc of npcs(n)) { const a = npcAt(npc, t); const id = `n${n}.${npc.who}`; const px = prevFig.current.get(id) ?? a.x; prevFig.current.set(id, a.x); near.push({ id, x: a.x, y: a.y, dx: a.x - px }); }
        for (const o of others.current.values()) if (Math.abs(o.y - by) < 400) { const id = `u${o.uid}`; const px = prevFig.current.get(id) ?? o.x; prevFig.current.set(id, o.x); near.push({ id, x: o.x, y: o.y, dx: o.x - px }); }
        const figs = figPlats(near);
        while (acc >= DT) {
          const plats = [...figs, ...around(body.current.y)];
          const dead = new Set([...crumbled.current].filter(([, at]) => t - at > 0.7).map(([id]) => id));
          let b = collide(step(body.current, input.current, DT, plats, t, dead), near);
          if (b.on?.kind === 'crumble' && !crumbled.current.has(b.on.id)) crumbled.current.set(b.on.id, t);
          // 주민이 민다
          const n0 = Math.floor(b.y / BAND_H);
          for (const n of [n0, n0 + 1]) for (const npc of npcs(n)) { const s = shoved(b, npcAt(npc, t)); if (s) { b = s; break; } }
          if (b.y < 0) { b = { ...b, y: 0, vy: 0 }; }
          body.current = b;
          acc -= DT;
        }
        // 부서진 발판은 8초 뒤 돌아온다
        for (const [id, at] of crumbled.current) if (t - at > 8) crumbled.current.delete(id);
        if (body.current.y > bestRef.current) bestRef.current = body.current.y;
        // 서버로 10Hz
        if (ws.current?.readyState === 1 && now - sent > 100) {
          sent = now; const b = body.current;
          ws.current.send(JSON.stringify({ t: 'pos', x: Math.round(b.x), y: Math.round(b.y), pose: poseOf(b), face: b.face }));
        }
      }
      // 다른 사람 보간
      for (const o of others.current.values()) { o.x += (o.tx - o.x) * Math.min(1, dt * 12); o.y += (o.ty - o.y) * Math.min(1, dt * 12); }
      // 카메라: 나는 나를 따라간다. 구경꾼은 로그인한 사람 중 아무나 한 명을 12초씩 따라간다(오르는 중이면 그 사람 우선,
      // 아무도 없으면 쉬는 사람 — 빈 바닥이 아니라 앉아 있는 사람들이 보여야 한다). 휠·드래그로 직접 보면 8초 동안 멈춘다
      let targetY = body.current.y;
      if (spectator) {
        const all = [...others.current.values()];
        if (now < tour.current.manualUntil) targetY = tour.current.y;
        else {
          if (!all.some((o) => o.uid === tour.current.uid) || now > tour.current.until) {
            const pool = all.filter((o) => o.status === 'active').length ? all.filter((o) => o.status === 'active') : all;
            const pick = pool[Math.floor(Math.random() * pool.length)];
            tour.current.uid = pick?.uid ?? 0; tour.current.until = now + 12000;
          }
          const f = all.find((o) => o.uid === tour.current.uid);
          tour.current.y = f ? f.y : 0; targetY = tour.current.y;
        }
      }
      cam.current += (targetY - cam.current) * Math.min(1, dt * 6);

      // ── 그리기 ──
      const W = c.width, H = c.height; const scale = W / WORLD_W;
      const sx = (x: number) => x * scale;
      const sy = (y: number) => H * 0.62 - (y - cam.current) * scale;
      ctx.fillStyle = '#f4f1f2'; ctx.fillRect(0, 0, W, H);
      // 높이 눈금
      ctx.fillStyle = '#d7d2d5'; ctx.font = `${11 * scale}px ui-monospace, monospace`; ctx.textAlign = 'left';
      const m0 = Math.floor((cam.current - H / scale) / 100) * 100;
      for (let m = Math.max(0, m0); m < cam.current + H / scale; m += 100) { const yy = sy(m); ctx.fillRect(0, yy, W, 1); ctx.fillText(`${m / 10}m`, 6 * scale, yy - 4 * scale); }
      clicks.length = 0;
      const n0 = Math.max(0, Math.floor((cam.current - H / scale) / BAND_H));
      const n1 = Math.floor((cam.current + H / scale) / BAND_H) + 1;
      for (let n = n0; n <= n1; n++) {
        for (const p of band(n)) {
          if (crumbled.current.has(p.id) && t - (crumbled.current.get(p.id) ?? 0) > 0.7) continue;
          const px = sx(platX(p, t)), py = sy(p.y), pw = p.w * scale;
          ctx.fillStyle = p.kind === 'rest' ? '#b9b1b6' : p.kind === 'ice' ? '#cfe6f0' : p.kind === 'spring' ? '#e8c96a' : p.kind === 'crumble' ? '#d9c2b2' : p.kind === 'short' ? '#c9a0b8' : '#8f8489';
          const th = (p.kind === 'rest' ? 14 : 9) * scale;
          ctx.fillRect(px, py, pw, th);
          if (p.kind === 'spring') { ctx.strokeStyle = '#8a6d1a'; ctx.lineWidth = 2 * scale; ctx.beginPath(); for (let k = 0; k < 4; k++) { ctx.moveTo(px + pw * (0.2 + 0.2 * k), py); ctx.lineTo(px + pw * (0.3 + 0.2 * k), py + th); } ctx.stroke(); }
          if (p.kind === 'ice') { ctx.fillStyle = '#ffffff'; ctx.fillRect(px + 4 * scale, py + 2 * scale, pw * 0.4, 2 * scale); }
          if (p.kind === 'crumble' && crumbled.current.has(p.id)) { ctx.fillStyle = '#f4f1f2'; for (let k = 1; k < 5; k++) ctx.fillRect(px + pw * k / 5, py, 2 * scale, th); }
          if (p.kind === 'move') { ctx.fillStyle = '#5b4f56'; ctx.fillRect(px + pw / 2 - 2 * scale, py + th, 4 * scale, 6 * scale); }
        }
        // 주민 NPC
        for (const npc of npcs(n)) {
          const a = npcAt(npc, t); const r = residents[npc.who];
          const fx = sx(a.x), fy = sy(a.y);
          figure(ctx, fx, fy, scale, a.pose, a.face, '#3a2f36', t, npc.role === 'shover' && a.shove);
          label(ctx, fx, fy, scale, r.handle, true, clicks, `/@${r.handle.toLowerCase().replace(/ /g, '-')}`);
          if (npc.role === 'rester' && r.line && Math.floor(t / 9 + npc.phase) % 3 === 0) bubble(ctx, fx, fy, scale, r.line);
        }
      }
      // 다른 사람들
      for (const o of others.current.values()) {
        if (o.y < cam.current - H / scale || o.y > cam.current + H / scale) continue;
        const fx = sx(o.x), fy = sy(o.y);
        figure(ctx, fx, fy, scale, o.status === 'rest' ? 'sit' : o.pose, o.face, figureColor(o.uid), t, false);
        label(ctx, fx, fy, scale, o.handle, false, clicks, `/@${o.handle.toLowerCase().replace(/ /g, '-')}`);
        const sd = said.current.get(o.uid); if (sd && now < sd.until) bubble(ctx, fx, fy, scale, sd.body);
      }
      // 나
      if (!spectator && ready.current) {
        const b = body.current; const fx = sx(b.x), fy = sy(b.y);
        figure(ctx, fx, fy, scale, poseOf(b), b.face, figureColor(me!.id), t, false);
        label(ctx, fx, fy, scale, me!.handle, false, clicks, '');
        const sd = said.current.get(me!.id); if (sd && now < sd.until) bubble(ctx, fx, fy, scale, sd.body);
      }
      // 아래로 떨어지는 사람 눈에 띄게 — 바닥 그림자 생략. HUD 는 React 로
      if (now - hudAt > 250) {
        hudAt = now;
        const list = [...others.current.values()];
        setHud({ h: metres(body.current.y), best: metres(bestRef.current), online: list.filter((o) => o.status === 'active').length + (spectator ? 0 : 1), resting: list.filter((o) => o.status === 'rest').length, connected: ws.current?.readyState === 1 });
      }
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); c.removeEventListener('click', onClick); c.removeEventListener('wheel', onWheel); c.removeEventListener('pointerdown', onPD); c.removeEventListener('pointermove', onPM); c.removeEventListener('pointerup', onPU); c.removeEventListener('pointerleave', onPU); };
  }, [residents, me, spectator]);

  // 캔버스 해상도 — 컨테이너 폭에 맞춘다
  useEffect(() => {
    const c = canvas.current!, w = wrap.current!;
    const fit = () => { const width = Math.min(960, w.clientWidth); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (VIEW_H / 960) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (VIEW_H / 960)}px`; };
    fit(); const ro = new ResizeObserver(fit); ro.observe(w); return () => ro.disconnect();
  }, []);

  const say = () => {
    const body = line.trim(); if (!body || !ws.current || ws.current.readyState !== 1) return;
    ws.current.send(JSON.stringify({ t: 'chat', body })); if (me) said.current.set(me.id, { body, until: performance.now() + 4000 }); setLine('');
  };
  const hold = (k: 'left' | 'right') => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex items-center justify-between font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{spectator ? `Watching · ${Math.round(cam.current / 10)}m` : `${hud.h}m · best ${hud.best}m`}</span>
        <span><span className={`mr-1 inline-block size-2 rounded-full ${hud.connected ? 'bg-[#34c759]' : 'bg-hairline'}`} />{hud.online} climbing · {hud.resting} resting</span>
      </div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#f4f1f2]">
        <canvas ref={canvas} className="block w-full touch-none" />
        {spectator && (
          <div className="absolute inset-x-0 bottom-0 flex items-center justify-between bg-paper/90 px-3 py-2 text-[12.5px]">
            <span>You are watching — scroll or drag to look around. Log in and your stick figure appears at the bottom.</span>
            <a href="/login?mode=signup" className="font-bold underline underline-offset-2">Log in</a>
          </div>
        )}
        {!spectator && TOUCH && (
          <div className="absolute inset-x-0 bottom-0 flex justify-between p-2">
            <div className="flex gap-2">
              <button {...hold('left')} className="size-14 rounded-full bg-ink/70 text-paper text-xl">←</button>
              <button {...hold('right')} className="size-14 rounded-full bg-ink/70 text-paper text-xl">→</button>
            </div>
            <button onPointerDown={() => { input.current.jump = true; }} onPointerUp={() => { input.current.jump = false; }} onPointerLeave={() => { input.current.jump = false; }} className="size-14 rounded-full bg-accent text-paper text-xl">↑</button>
          </div>
        )}
      </div>
      {!spectator && !TOUCH && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">← → run · hold SPACE to charge, release to jump · steer a little in the air · fall far and you splat · stand still to rest · click a figure to visit them</p>}
      {/* 채팅 — 성의 없게. 저장 안 함 */}
      <div className="mt-3 rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[12.5px]">
        <div className="max-h-24 overflow-y-auto">
          {chats.length === 0 ? <span className="text-ink-soft">…</span> : chats.map((c, i) => <div key={i}><b>{c.who}</b> {c.body}</div>)}
        </div>
        {!spectator && (
          <div className="mt-1 flex gap-1.5">
            <input value={line} onChange={(e) => setLine(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') say(); }} maxLength={140} placeholder="say something"
              className="min-w-0 flex-1 rounded border border-hairline bg-surface px-2 py-1 outline-none focus:border-ink" />
            <button onClick={say} className="rounded border border-hairline px-2 font-bold">send</button>
          </div>
        )}
      </div>
    </div>
  );
}

function label(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string, ai: boolean, clicks: { x: number; y: number; w: number; h: number; href: string }[], href: string) {
  ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillStyle = '#5b4f56';
  const t = text; void ai; // 졸라맨 위엔 AI 표기를 붙이지 않는다(운영자, 2026-09-22) — 주민임은 이름·직업으로 충분하고 사이트의 다른 곳이 AI 배지를 단다
  ctx.fillText(t, x, y - 54 * s);
  const w = ctx.measureText(t).width;
  if (href) clicks.push({ x: x - w / 2, y: y - 64 * s, w, h: 64 * s, href });
}
function bubble(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) {
  ctx.font = `${11 * s}px system-ui, sans-serif`; ctx.textAlign = 'left';
  const t = text.length > 42 ? `${text.slice(0, 40)}…` : text;
  const w = ctx.measureText(t).width + 14 * s, h = 20 * s;
  const bx = Math.min(ctx.canvas.width - w - 4, Math.max(4, x - w / 2)), by = y - 88 * s;
  ctx.fillStyle = '#ffffff'; ctx.strokeStyle = '#b9b1b6'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.roundRect(bx, by, w, h, 6 * s); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#1b0c15'; ctx.fillText(t, bx + 7 * s, by + 14 * s);
}
