'use client';
import { useEffect, useRef, useState } from 'react';
import { ListChecks, Upload } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { figure } from '@/lib/stickman';
import { figureColor, hash, rng } from '@/lib/tower';
import { BADGE_BY_KEY } from '@/lib/pond';
import { CHASE_SEC, CHASE_SPEED, DEPTH_PX, GRAB_R, ITEMS, PLAYER_SPEED, RESIDENT_SPEED, routineAt, residentsOut, SHOVE_R, SPOTS, SQUARE_W, spotOf, WATER, type Activity, type ItemKey, type Routine, type Task } from '@/lib/goose';

/**
 * Square — 화면. Climb 과 같은 졸라맨·점프·밀기, 다만 2.5D 광장이다. 사람이 AI 주민을 괴롭힌다.
 * ←→↑↓ 걷기 · SPACE 점프 · X 밀기(닿은 주민이 넘어지고 물건을 떨어뜨린다) · C 물건 줍기/뺏기/놓기.
 * 주민은 일과를 돌다가(씨앗·시각) 맞으면 넘어지고, 물건을 뺏기면 몇 초 쫓아오고(잡히면 되찾아 감), 포기하면 일과로 돌아간다.
 * 오늘의 할 일 8개 — 완료 판정은 여기서, 기록·코인·뱃지는 /api/goose.
 */
export interface ResidentLite { id: number; handle: string; line: string }
interface Me { id: number; handle: string }
interface Other { uid: number; handle: string; x: number; tx: number; d: number; td: number; pose: string; status: 'active' | 'rest' }
interface Npc { rt: Routine; x: number; d: number; face: 1 | -1; item: ItemKey | null; mode: 'routine' | 'down' | 'chase' | 'return' | 'flee' | 'fetch'; until: number; target: Loose | null; say: string; sayUntil: number; act: Activity; moving: boolean; angry: boolean; threw: number; swing: number }
interface Loose { item: ItemKey; x: number; d: number; from: number | null; dunked?: string }

const VIEW_W = 960, VIEW_H = 470, GROUND = 330, TOP = GROUND - DEPTH_PX;
const TOUCH = typeof window !== 'undefined' && 'ontouchstart' in window;
const dy = (d: number) => TOP + d * DEPTH_PX; const ds = (d: number) => 0.7 + 0.3 * d;
const dist = (ax: number, ad: number, bx: number, bd: number) => Math.hypot(ax - bx, (ad - bd) * 400);

export interface Content { shoved: string[]; chase: string[]; giveup: string[]; caught: string[]; angry: string[]; thrown: string[] }
export function SquareGame({ residents, me, tasks, done, content }: { residents: ResidentLite[]; me: Me | null; tasks: Task[]; done: string[]; content: Content }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const wrap = useRef<HTMLDivElement>(null);
  const ws = useRef<WebSocket | null>(null);
  const body = useRef({ x: 1500, d: 0.7, z: 0, vz: 0, face: 1 as 1 | -1, moving: false, carry: null as ItemKey | null, carryFrom: null as number | null, stack: [] as ItemKey[], hurt: 0, swing: 0, swingKind: 'punch' as 'punch' | 'kick' });
  const thrown = useRef<{ item: ItemKey; x: number; d: number; z: number; vx: number; vz: number; from: number }[]>([]);
  const broken = useRef(new Map<string, { hp: number; brokeAt: number }>()); // 소품 내구도 — 세 대면 부서지고 2분 뒤 돌아온다
  const input = useRef({ left: false, right: false, up: false, down: false, jump: false, grab: false, shove: false, kick: false });
  const npcs = useRef<Npc[]>([]);
  const loose = useRef<Loose[]>([]);
  const others = useRef(new Map<number, Other>());
  const cam = useRef(0);
  const tour = useRef({ uid: 0, until: 0 });
  const stats = useRef({ shoves: [] as { who: number; at: number }[], chasedSince: 0, chasedBy: -1, doneKeys: new Set(done) });
  const [doneList, setDoneList] = useState<string[]>(done);
  const [toast, setToast] = useState('');
  const [chats, setChats] = useState<{ who: string; body: string }[]>([]);
  const [line, setLine] = useState('');
  const [hud, setHud] = useState({ online: 0, carry: '' });
  const [showTasks, setShowTasks] = useState(!TOUCH);
  const spectator = !me;

  // ── 방 ──
  useEffect(() => {
    let alive = true, sock: WebSocket | null = null, retry = 0;
    const connect = () => {
      if (!alive) return;
      sock = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws/square`); ws.current = sock;
      sock.onopen = () => { retry = 0; };
      sock.onmessage = (e) => {
        let m: { t: string; [k: string]: unknown }; try { m = JSON.parse(String(e.data)); } catch { return; }
        const map = others.current;
        const put = (u: Record<string, unknown>) => {
          const uid = Number(u.uid); const d = Math.min(1, Math.max(0, (Number(u.y) || 700) / 1000));
          if (me && uid === me.id) { if (m.t === 'init') { body.current.x = Number(u.x) || 1500; body.current.d = d; cam.current = body.current.x - VIEW_W / 2; } return; }
          const prev = map.get(uid);
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

  const complete = async (key: string) => {
    if (stats.current.doneKeys.has(key) || !tasks.some((t) => t.key === key)) return;
    stats.current.doneKeys.add(key); setDoneList([...stats.current.doneKeys]);
    const t = tasks.find((x) => x.key === key)!;
    setToast(`Done: ${t.text} (+${t.coins})`); setTimeout(() => setToast(''), 3500);
    if (!me) return;
    const res = await fetch('/api/goose', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ key }) });
    const d = await res.json().catch(() => ({})) as { ok?: boolean };
    if (!d.ok) { stats.current.doneKeys.delete(key); setDoneList([...stats.current.doneKeys]); }
  };

  // ── 입력 ──
  useEffect(() => {
    if (spectator) return;
    const typing = () => { const el = document.activeElement; return el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement; };
    const set = (k: string, v: boolean, e: KeyboardEvent) => {
      const i = input.current;
      if (k === 'ArrowLeft' || k === 'a') i.left = v; else if (k === 'ArrowRight' || k === 'd') i.right = v;
      else if (k === 'ArrowUp' || k === 'w') i.up = v; else if (k === 'ArrowDown' || k === 's') i.down = v;
      else if (k === ' ') i.jump = v; else if (k === 'c' || k === 'C' || k === 'Enter') i.grab = v; else if (k === 'x' || k === 'X') i.shove = v; else if (k === 'z' || k === 'Z' || k === 'Shift') i.kick = v; else return;
      e.preventDefault();
    };
    const kd = (e: KeyboardEvent) => { if (!typing()) set(e.key, true, e); }; const ku = (e: KeyboardEvent) => { if (!typing()) set(e.key, false, e); };
    window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, [spectator]);

  // ── 루프 ──
  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    let raf = 0, last = performance.now(), sent = 0, hudAt = 0, jumpWas = false, grabWas = false, shoveWas = false, kickWas = false;
    const hour = () => Math.floor(Date.now() / 3600000); let curHour = hour();
    // 이 시간의 주민 + 오늘의 할 일에 이름이 오른 주민(그 사람은 하루 종일 광장에 있어야 할 일이 가능하다)
    const spawn = () => { const h = hour(); const base = residentsOut(h, residents.length); const dayset = residentsOut(h - (h % 24), residents.length);
      for (const t of tasks) { if (t.who !== undefined && !base.some((r) => r.who === t.who)) { const rt = dayset.find((r) => r.who === t.who); if (rt) base.push(rt); } }
      // 성깔 있는 주민(순찰이 정한 목록 + 씨앗 30%) 은 맞으면 되갚고, 쫓을 때 물건을 던진다
      npcs.current = base.map((rt) => { const p = routineAt(rt, Date.now() / 1000); const angry = content.angry.includes(residents[rt.who].handle) || rt.seed % 10 < 3; return { rt, x: p.x, d: p.d, face: p.face, item: rt.item, mode: 'routine' as const, until: 0, say: '', sayUntil: 0, act: p.act, moving: p.moving, angry, threw: 0, swing: 0, target: null }; }); loose.current = []; thrown.current = []; };
    spawn();
    const props = PROPS();
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.1, (now - last) / 1000); last = now; const t = Date.now() / 1000;
      if (hour() !== curHour) { curHour = hour(); spawn(); }
      const b = body.current, i = input.current, st = stats.current;
      const knock = (who: number, line: string) => { // 반격 — 나는 넘어지고 들고 있던 걸 다 흘린다
        b.hurt = 1.2; b.vz = 0; b.z = 0;
        for (const it of b.stack) loose.current.push({ item: it, x: b.x + (Math.random() - 0.5) * 80, d: Math.max(0, Math.min(1, b.d + (Math.random() - 0.5) * 0.2)), from: null });
        b.stack = []; setToast(`${residents[who].handle}: ${line}`); setTimeout(() => setToast(''), 2500); st.chasedSince = 0;
      };
      /** 때리기/차기 — 앞의 주민은 넘어지고 물건을 놓친다, 앞의 소품은 내구도가 깎인다(차기는 두 배) */
      const hit = (kind: 'punch' | 'kick') => {
        b.swing = 0.28; b.swingKind = kind;
        const air = kind === 'kick' && b.z > 0; // 점프킥 — 더 멀리 날리고 더 오래 눕힌다
        const reach = kind === 'kick' ? SHOVE_R + (air ? 36 : 24) : SHOVE_R + 10;
        const n = npcs.current.filter((p) => p.mode !== 'down' && dist(b.x, b.d, p.x, p.d) < reach && Math.sign(p.x - b.x) === b.face).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
        if (n) {
          n.mode = 'down'; n.until = now + (air ? 2600 : kind === 'kick' ? 1900 : 1400); n.face = (-b.face) as 1 | -1; n.x += b.face * (air ? 80 : kind === 'kick' ? 44 : 22);
          if (air) { setToast('Jump kick.'); setTimeout(() => setToast(''), 1200); }
          n.say = pick(content.shoved); n.sayUntil = now + 2000;
          if (n.item) { loose.current.push({ item: n.item, x: n.x + b.face * 26, d: n.d, from: n.rt.who }); n.item = null; }
          st.shoves = [...st.shoves.filter((x) => now - x.at < 10000), { who: n.rt.who, at: now }];
          if (new Set(st.shoves.map((x) => x.who)).size >= 3) void complete('shove3');
          return;
        }
        const pr = props.filter((p) => BREAKABLE.includes(p.kind) && dist(b.x, b.d, p.x, p.d) < reach + 30 && Math.sign(p.x - b.x + 0.01) === b.face).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
        if (pr) {
          const st2 = broken.current.get(pr.key) ?? { hp: 3, brokeAt: 0 };
          if (st2.brokeAt) return;
          st2.hp -= air ? 3 : kind === 'kick' ? 2 : 1;
          if (st2.hp <= 0) { st2.brokeAt = now; setToast(`You broke ${pr.name}.`); setTimeout(() => setToast(''), 2500); void complete(`break:${pr.key}`); for (const m of npcs.current) if (m.mode === 'routine' && dist(m.x, m.d, pr.x, pr.d) < 260) { m.say = pick(content.shoved); m.sayUntil = now + 2000; if (m.angry) { m.mode = 'chase'; m.until = now + CHASE_SEC * 1000; } } }
          broken.current.set(pr.key, st2);
        }
      };
      // ── 나 ──
      if (!spectator && b.hurt > 0) { b.hurt = Math.max(0, b.hurt - dt); b.moving = false; }
      if (b.swing > 0) b.swing = Math.max(0, b.swing - dt);
      if (!spectator && b.hurt <= 0) {
        const dx = (i.right ? 1 : 0) - (i.left ? 1 : 0), dd = (i.down ? 1 : 0) - (i.up ? 1 : 0);
        const slow = 1 - Math.min(0.5, b.stack.length * 0.12); // 물건 많이 들면 느리다
        if (dx || dd) { b.x = Math.max(20, Math.min(SQUARE_W - 20, b.x + dx * PLAYER_SPEED * slow * dt)); b.d = Math.max(0, Math.min(1, b.d + dd * 1.5 * dt)); if (dx) b.face = dx as 1 | -1; }
        b.moving = !!(dx || dd);
        if (i.jump && !jumpWas && b.z === 0) b.vz = 560;
        if (b.z > 0 || b.vz > 0) { b.vz -= 1900 * dt; b.z = Math.max(0, b.z + b.vz * dt); if (b.z === 0) b.vz = 0; }
        // 때리기(X)·차기(Z) — 주민은 넘어지고, 소품은 부서진다
        if (i.shove && !shoveWas && b.z === 0 && b.swing <= 0) hit('punch');
        if (i.kick && !kickWas && b.swing <= 0) hit('kick'); // 공중이면 점프킥
        // 줍기/뺏기/놓기 — 손에 있으면 놓고, 없으면 바닥 것 → 주민 것 순
        if (i.grab && !grabWas && b.z === 0) {
          if (b.stack.length) {
            const it = b.stack.pop()!;
            const water = SPOTS.find((s) => WATER.includes(s.key) && dist(b.x, b.d, s.x, s.d) < 90);
            const spotNear = SPOTS.find((s) => (s.kind === 'bench' || s.kind === 'cafe') && dist(b.x, b.d, s.x, s.d) < 90);
            loose.current.push({ item: it, x: b.x + b.face * 18, d: b.d, from: null, dunked: water?.key });
            if (water) { void complete(`dunk:${it}:${water.key}`); setToast(`Splash. The ${ITEMS[it]} is in ${water.name}.`); setTimeout(() => setToast(''), 2500); }
            if (spotNear) void complete(`deliver:${it}:${spotNear.key}`);
          } else {
            const l = loose.current.filter((x) => !x.dunked && dist(b.x, b.d, x.x, x.d) < GRAB_R).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
            if (l) { loose.current = loose.current.filter((x) => x !== l); b.stack.push(l.item); if (l.from !== null) { const n = npcs.current.find((p) => p.rt.who === l.from); if (n && n.mode !== 'down') { n.mode = 'chase'; n.until = now + CHASE_SEC * 1000; } if (n) { void complete(`steal:${n.rt.who}`); } } }
            else {
              const n = npcs.current.filter((p) => p.item && p.mode !== 'down' && dist(b.x, b.d, p.x, p.d) < GRAB_R + 6).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
              if (n && n.item) { b.stack.push(n.item); n.item = null; n.mode = 'chase'; n.until = now + CHASE_SEC * 1000; n.say = pick(content.chase); n.sayUntil = now + 2500; void complete(`steal:${n.rt.who}`); }
            }
            if (b.stack.length >= 3) void complete('collect3');
          }
        }
        jumpWas = i.jump; grabWas = i.grab; shoveWas = i.shove; kickWas = i.kick;
        if (ws.current?.readyState === 1 && now - sent > 150) { sent = now; ws.current.send(JSON.stringify({ t: 'pos', x: Math.round(b.x), y: Math.round(b.d * 1000), pose: b.z > 0 ? 'jump' : b.moving ? 'run' : 'stand', face: b.face })); }
      }
      // ── 주민 ──
      let chasing = -1;
      for (const n of npcs.current) {
        const base = routineAt(n.rt, t);
        if (n.swing > 0) n.swing -= dt;
        if (n.mode === 'down') { if (now > n.until) { if (n.angry && !spectator) { n.mode = 'chase'; n.until = now + CHASE_SEC * 1000; n.say = pick(content.chase); n.sayUntil = now + 2000; } else n.mode = 'return'; } n.moving = false; continue; }
        if (n.mode === 'chase') {
          chasing = n.rt.who;
          if (now > n.until || spectator) { n.mode = 'return'; n.say = pick(content.giveup); n.sayUntil = now + 2500; void complete(`sit:${n.rt.who}`); continue; }
          // 옆 주민이 합류한다(가끔, 3초) — 떼로 몰려오면 도망갈 맛이 난다
          for (const m of npcs.current) if (m !== n && m.mode === 'routine' && dist(m.x, m.d, n.x, n.d) < 220 && Math.random() < 0.004) { m.mode = 'chase'; m.until = now + 3000; m.say = pick(content.chase); m.sayUntil = now + 1500; }
          // 들고 있는 게 있고 거리가 애매하면 던진다(4초에 한 번)
          const far = dist(n.x, n.d, b.x, b.d);
          if (n.item && far > 70 && far < 170 && now - n.threw > 4000 && b.hurt <= 0) { n.threw = now; n.swing = 0.25; thrown.current.push({ item: n.item, x: n.x, d: n.d, z: 30, vx: Math.sign(b.x - n.x) * 380, vz: 120, from: n.rt.who }); n.item = null; n.say = pick(content.thrown); n.sayUntil = now + 1500; }
          const ddx = b.x - n.x, ddd = b.d - n.d; const len = Math.hypot(ddx, ddd * 400) || 1;
          n.x += (ddx / len) * CHASE_SPEED * dt; n.d = Math.max(0, Math.min(1, n.d + (ddd * 400 / len) * CHASE_SPEED * dt / 400)); n.face = ddx >= 0 ? 1 : -1; n.moving = true;
          if (dist(n.x, n.d, b.x, b.d) < 26 && b.z === 0 && b.hurt <= 0) { // 잡았다 — 한 대 치고(넘어짐, 물건 다 흘림) 자기 것을 챙긴다
            n.swing = 0.28; const mine = b.stack.find((it) => it === n.rt.item);
            knock(n.rt.who, pick(content.caught));
            const back = loose.current.find((l) => l.item === (mine ?? n.rt.item) && !l.dunked); if (back) { loose.current = loose.current.filter((l) => l !== back); n.item = back.item; }
            n.mode = 'return';
          }
          continue;
        }
        if (n.mode === 'return') { // 일과 자리로 돌아간다 — 도착하면 routine
          const ddx = base.x - n.x, ddd = base.d - n.d; const len = Math.hypot(ddx, ddd * 400);
          if (len < 12) { n.mode = 'routine'; } else { n.x += (ddx / len) * RESIDENT_SPEED * dt; n.d += (ddd * 400 / len) * RESIDENT_SPEED * dt / 400; n.face = ddx >= 0 ? 1 : -1; n.moving = true; }
          continue;
        }
        if (n.mode === 'fetch') { // 어질러진 물건을 주우러 간다 — 도착하면 줍고, 자기 게 아니면 주인에게 돌려주러 간다
          const tg = n.target;
          if (!tg || !loose.current.includes(tg)) { n.mode = 'return'; n.target = null; continue; }
          const ddx = tg.x - n.x, ddd = tg.d - n.d; const len = Math.hypot(ddx, ddd * 400);
          if (len < 16) {
            loose.current = loose.current.filter((l) => l !== tg); n.target = null;
            if (tg.from === n.rt.who || tg.from === null || !n.item) { n.item = tg.item; n.mode = 'return'; n.say = pick(['there.', 'honestly', 'who does this', 'picked it up. again.', 'this is mine now']); n.sayUntil = now + 2000; }
            else { const owner = npcs.current.find((m) => m.rt.who === tg.from); if (owner && !owner.item) owner.item = tg.item; n.mode = 'return'; }
          } else { n.x += (ddx / len) * RESIDENT_SPEED * dt; n.d += (ddd * 400 / len) * RESIDENT_SPEED * dt / 400; n.face = ddx >= 0 ? 1 : -1; n.moving = true; }
          continue;
        }
        n.x = base.x; n.d = base.d; n.face = base.face; n.act = base.act; n.moving = base.moving;
        // 어질러진 것에 반응: 자기 물건은 어디 있든 가지러 간다, 남의 것도 가까우면(성깔 있는 주민은 더 멀리서) 주워서 정리한다
        if (b.hurt <= 0 || spectator) {
          const mine = loose.current.find((l) => l.from === n.rt.who && !l.dunked);
          const near = loose.current.find((l) => !l.dunked && dist(n.x, n.d, l.x, l.d) < (n.angry ? 420 : 200));
          const tg = (!n.item && mine) || (Math.random() < 0.01 ? near : null);
          if (tg && !npcs.current.some((m) => m.target === tg)) { n.mode = 'fetch'; n.target = tg; if (tg === near && tg !== mine) { n.say = pick(['ugh', 'someone left this', 'not mine but ok', 'i will just', 'the state of this square']); n.sayUntil = now + 1800; } }
        }
      }
      // 던져진 물건 — 포물선, 맞으면 넘어짐, 땅에 떨어지면 바닥에
      for (const th of [...thrown.current]) {
        th.x += th.vx * dt; th.vz -= 700 * dt; th.z += th.vz * dt;
        if (!spectator && b.hurt <= 0 && Math.abs(th.x - b.x) < 22 && Math.abs(th.d - b.d) < 0.12 && th.z < 50 + b.z && th.z > b.z - 10) { knock(th.from, pick(content.thrown)); thrown.current = thrown.current.filter((x) => x !== th); loose.current.push({ item: th.item, x: th.x, d: th.d, from: th.from }); continue; }
        if (th.z <= 0) { thrown.current = thrown.current.filter((x) => x !== th); loose.current.push({ item: th.item, x: th.x, d: th.d, from: th.from }); }
      }
      // 부서진 소품은 2분 뒤 돌아온다
      for (const [k, v] of broken.current) if (v.brokeAt && now - v.brokeAt > 120000) broken.current.delete(k);
      // 쫓기는 시간 재기
      if (chasing >= 0) { if (st.chasedBy !== chasing) { st.chasedBy = chasing; st.chasedSince = now; } else if (now - st.chasedSince > 10000) void complete('chased'); } else { st.chasedBy = -1; st.chasedSince = 0; }
      // 카메라·다른 사람
      let target = b.x;
      if (spectator) {
        const all = [...others.current.values()];
        if (!all.some((o) => o.uid === tour.current.uid) || now > tour.current.until) { const pool = all.filter((o) => o.status === 'active').length ? all.filter((o) => o.status === 'active') : all; const p = pool[Math.floor(Math.random() * pool.length)]; tour.current = { uid: p?.uid ?? 0, until: now + 12000 }; }
        const f = all.find((o) => o.uid === tour.current.uid); target = f ? f.x : 1600;
      }
      cam.current += (Math.max(0, Math.min(SQUARE_W - VIEW_W, target - VIEW_W / 2)) - cam.current) * Math.min(1, dt * 6);
      for (const o of others.current.values()) { o.x += (o.tx - o.x) * Math.min(1, dt * 10); o.d += (o.td - o.d) * Math.min(1, dt * 10); }

      // ── 그리기 ──
      const W = c.width, H = c.height, s = W / VIEW_W; const sx = (wx: number) => (wx - cam.current) * s;
      ctx.fillStyle = '#eef0f2'; ctx.fillRect(0, 0, W, H);
      // 뒤 건물 실루엣(시차)
      ctx.fillStyle = '#dcd8db'; for (let k = 0; k < 40; k++) { const bx = ((k * 173 - cam.current * 0.4) % (SQUARE_W + 400) + SQUARE_W + 400) % (SQUARE_W + 400) - 200; const bh = 40 + (k * 37) % 60; ctx.fillRect(bx * s, (TOP - bh) * s, 90 * s, bh * s); }
      // 광장 바닥: 뒤 어둡고 앞 밝게 + 돌 무늬
      const g = ctx.createLinearGradient(0, TOP * s, 0, (GROUND + 40) * s); g.addColorStop(0, '#cfc7c2'); g.addColorStop(1, '#e6e0da'); ctx.fillStyle = g; ctx.fillRect(0, TOP * s, W, (GROUND + 40 - TOP) * s);
      ctx.strokeStyle = 'rgba(0,0,0,0.06)'; ctx.lineWidth = 1; for (let k = 0; k < 6; k++) { const yy = dy(k / 5) * s; ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(W, yy); ctx.stroke(); } for (let px = -((cam.current * s) % (80 * s)); px < W; px += 80 * s) { ctx.beginPath(); ctx.moveTo(px, TOP * s); ctx.lineTo(px, (GROUND + 40) * s); ctx.stroke(); }
      type Draw = { d: number; f: () => void }; const layer: Draw[] = [];
      for (const p of props) { const fx = sx(p.x); if (fx < -200 || fx > W + 200) continue; const bs = broken.current.get(p.key); layer.push({ d: p.d, f: () => prop(ctx, p.kind, fx, dy(p.d) * s, ds(p.d) * s, p.seed, t, loose.current.filter((l) => l.dunked === p.key), bs ? (bs.brokeAt ? 'broken' : bs.hp < 3 ? 'cracked' : 'ok') : 'ok') }); }
      for (const th of thrown.current) { const fx = sx(th.x); layer.push({ d: th.d, f: () => item(ctx, th.item, fx, (dy(th.d) - th.z) * s - 6 * s, ds(th.d) * s) }); }
      for (const l of loose.current) { if (l.dunked) continue; const fx = sx(l.x); if (fx < -50 || fx > W + 50) continue; layer.push({ d: l.d - 0.001, f: () => item(ctx, l.item, fx, dy(l.d) * s - 6 * s, ds(l.d) * s) }); }
      for (const n of npcs.current) {
        const fx = sx(n.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: n.d, f: () => {
          const fy = dy(n.d) * s, fs = ds(n.d) * s;
          const pose = n.mode === 'down' ? 'hurt' : n.moving ? 'run' : n.act === 'sit' || n.act === 'eat' ? 'sit' : 'stand';
          if (n.mode === 'down') { ctx.save(); ctx.translate(fx, fy); ctx.rotate(n.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, '#3a2f36', t, false); ctx.restore(); }
          else if (n.swing > 0) figure(ctx, fx, fy, fs, 'punch', n.face, '#3a2f36', t, false);
          else figure(ctx, fx, fy, fs, pose, n.face, '#3a2f36', t + n.rt.seed % 5, n.act === 'read' || n.act === 'phone');
          if (n.item && n.mode !== 'down') item(ctx, n.item, fx + n.face * 14 * fs, fy - (n.item === 'hat' ? 50 : 26) * fs, fs * 0.8);
          if (n.act !== 'stand' && n.mode === 'routine' && !n.moving) actIcon(ctx, n.act, fx + 18 * fs, fy - 46 * fs, fs);
          name(ctx, fx, fy - 58 * fs, s, `${residents[n.rt.who].handle} ᴬᴵ`);
          if (now < n.sayUntil) bubble(ctx, fx, fy - 70 * fs, s, n.say);
        } });
      }
      for (const o of others.current.values()) {
        const fx = sx(o.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: o.d, f: () => { const fy = dy(o.d) * s, fs = ds(o.d) * s; figure(ctx, fx, fy, fs, (o.status === 'rest' ? 'sit' : o.pose === 'run' ? 'run' : o.pose === 'jump' ? 'jump' : 'stand'), 1, figureColor(o.uid), t, false); name(ctx, fx, fy - 58 * fs, s, o.handle); } });
      }
      if (!spectator) layer.push({ d: b.d, f: () => {
        const fx = sx(b.x), fy = (dy(b.d) - b.z) * s, fs = ds(b.d) * s;
        if (b.z > 0) { ctx.fillStyle = 'rgba(0,0,0,0.15)'; ctx.beginPath(); ctx.ellipse(fx, dy(b.d) * s, 12 * fs, 4 * fs, 0, 0, 6.29); ctx.fill(); }
        if (b.hurt > 0) { ctx.save(); ctx.translate(fx, fy); ctx.rotate(-b.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, figureColor(me!.id), t, false); ctx.restore(); }
        else figure(ctx, fx, fy, fs, b.swing > 0 ? b.swingKind : b.z > 0 ? 'jump' : b.moving ? 'run' : 'stand', b.face, figureColor(me!.id), t, false);
        b.stack.forEach((it, k) => item(ctx, it, fx, fy - (48 + k * 12) * fs, fs * 0.8)); // 머리 위로 쌓인다
        name(ctx, fx, fy - (58 + b.stack.length * 12) * fs, s, me!.handle);
      } });
      layer.sort((a, bb) => a.d - bb.d).forEach((l) => l.f());
      if (now - hudAt > 250) { hudAt = now; setHud({ online: [...others.current.values()].filter((o) => o.status === 'active').length + (spectator ? 0 : 1), carry: b.stack.map((x) => ITEMS[x]).join(', ') }); }
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [residents, me, spectator, tasks, content]);

  useEffect(() => {
    const c = canvas.current!, w = wrap.current!;
    const fit = () => { const width = Math.min(960, w.clientWidth); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (VIEW_H / VIEW_W) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (VIEW_H / VIEW_W)}px`; };
    fit(); const ro = new ResizeObserver(fit); ro.observe(w); return () => ro.disconnect();
  }, []);

  const say = () => { const b = line.trim(); if (!b || ws.current?.readyState !== 1) return; ws.current.send(JSON.stringify({ t: 'chat', body: b })); setLine(''); };
  const hold = (k: keyof typeof input.current) => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex flex-wrap items-center justify-between gap-2 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{spectator ? 'Watching the square' : hud.carry ? `carrying: ${hud.carry}` : 'The square'}</span>
        <span>{hud.online} here · {doneList.length}/{tasks.length} done today</span>
      </div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#eef0f2]">
        <canvas ref={canvas} className="block w-full touch-none" />
        {toast && <div className="absolute left-1/2 top-3 -translate-x-1/2 rounded-full bg-ink px-3 py-1 text-[12.5px] font-bold text-paper">{toast}</div>}
        {spectator && (
          <div className="absolute inset-x-0 bottom-0 flex items-center justify-between bg-paper/90 px-3 py-2 text-[12.5px]">
            <span>You are watching. Log in and you get a list of things to do to the residents.</span>
            <a href="/login?mode=signup" className="font-bold underline underline-offset-2">Log in</a>
          </div>
        )}
        {!spectator && TOUCH && (
          <div className="absolute inset-x-0 bottom-0 flex items-end justify-between p-2">
            <div className="grid grid-cols-3 gap-1"><span /><button {...hold('up')} className="size-12 rounded-full bg-ink/70 text-paper">↑</button><span /><button {...hold('left')} className="size-12 rounded-full bg-ink/70 text-paper">←</button><button {...hold('down')} className="size-12 rounded-full bg-ink/70 text-paper">↓</button><button {...hold('right')} className="size-12 rounded-full bg-ink/70 text-paper">→</button></div>
            <div className="flex gap-2"><button {...hold('jump')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Jump</button><button {...hold('shove')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Punch</button><button {...hold('kick')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Kick</button><button {...hold('grab')} className="size-12 rounded-full bg-accent text-[11px] font-bold text-paper">Grab</button></div>
          </div>
        )}
      </div>
      {!spectator && !TOUCH && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">← → ↑ ↓ walk · SPACE jump · X punch · Z kick (breaks things) · C grab / take / drop · drop things in the fountain or the pond · they chase, throw and hit back</p>}
      <div className="mt-3 rounded-xl border border-hairline bg-paper p-3">
        <button onClick={() => setShowTasks((v) => !v)} className="inline-flex items-center gap-1.5 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft"><ListChecks size={13} /> Today&apos;s list · {doneList.length}/{tasks.length}</button>
        {showTasks && (
          <ul className="mt-2 grid gap-1 text-[13px] sm:grid-cols-2">
            {tasks.map((t) => <li key={t.key} className={doneList.includes(t.key) ? 'line-through opacity-50' : ''}>☐ {t.text} <span className="font-mono text-[10.5px] text-ink-soft">+{t.coins}</span></li>)}
          </ul>
        )}
        {doneList.length >= tasks.length && tasks.length > 0 && <p className="mt-2 text-[12.5px] font-semibold text-accent-deep">All done. Badge: {BADGE_BY_KEY.get('g:day')?.name}. Come back tomorrow; they will have forgotten.</p>}
      </div>
      <div className="mt-3 rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[12.5px]">
        <div className="max-h-24 overflow-y-auto">{chats.length === 0 ? <span className="text-ink-soft">…</span> : chats.map((c, i) => <div key={i}><b>{c.who}</b> {c.body}</div>)}</div>
        {!spectator && <div className="mt-1 flex gap-1.5"><input value={line} onChange={(e) => setLine(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') say(); }} maxLength={140} placeholder="say something" className="min-w-0 flex-1 rounded border border-hairline bg-surface px-2 py-1 outline-none focus:border-ink" /><button onClick={say} className="rounded border border-hairline px-2 font-bold"><Upload size={12} /></button></div>}
      </div>
    </div>
  );
}

const pick = <T,>(xs: T[]) => xs[Math.floor(Math.random() * xs.length)];
function PROPS() {
  const r = rng(hash('square:props'));
  const out = SPOTS.map((s) => ({ key: s.key, name: s.name, kind: s.kind as string, x: s.x, d: s.d, seed: Math.floor(r() * 1e6) }));
  for (let k = 0; k < 10; k++) out.push({ key: `tree${k}`, name: 'a tree', kind: 'tree', x: 80 + r() * (SQUARE_W - 160), d: r() * 0.12, seed: Math.floor(r() * 1e6) });
  for (let k = 0; k < 6; k++) out.push({ key: `lamp${k}`, name: 'a lamp', kind: 'lamp', x: 200 + k * 520, d: 0.95, seed: k });
  return out;
}
const BREAKABLE = ['bench', 'lamp', 'booth', 'stall', 'garden', 'cafe'];
function prop(ctx: CanvasRenderingContext2D, kind: string, x: number, y: number, s: number, seed: number, t: number, dunked: Loose[], state: 'ok' | 'cracked' | 'broken' = 'ok') {
  const r = rng(seed); ctx.save(); ctx.translate(x, y); ctx.lineWidth = 1.5 * s; ctx.strokeStyle = '#3a2f36'; ctx.lineJoin = 'round';
  if (state === 'broken') { // 부서짐: 기울고 조각이 흩어진다
    ctx.rotate(0.35); ctx.globalAlpha = 0.75;
    ctx.fillStyle = '#8a8087'; for (let k = 0; k < 5; k++) ctx.fillRect((-40 + k * 18) * s, (-4 + (k % 2) * 3) * s, 8 * s, 4 * s);
  }
  if (state === 'cracked') { ctx.strokeStyle = '#1b0c15'; ctx.beginPath(); ctx.moveTo(-6 * s, -30 * s); ctx.lineTo(2 * s, -18 * s); ctx.lineTo(-4 * s, -8 * s); ctx.stroke(); ctx.strokeStyle = '#3a2f36'; }
  const F = (c: string) => { ctx.fillStyle = c; ctx.fill(); ctx.stroke(); };
  switch (kind) {
    case 'house': { const w = 120 * s, h = 90 * s; ctx.beginPath(); ctx.rect(-w / 2, -h, w, h); F(['#c9d6e6', '#e6d3a5', '#d9c2b2'][seed % 3]); ctx.beginPath(); ctx.moveTo(-w / 2 - 8 * s, -h); ctx.lineTo(0, -h - 40 * s); ctx.lineTo(w / 2 + 8 * s, -h); ctx.closePath(); F('#8b5a3a'); ctx.beginPath(); ctx.rect(-12 * s, -40 * s, 24 * s, 40 * s); F('#5b4f56'); for (const wx of [-40, 28]) { ctx.beginPath(); ctx.rect(wx * s, -70 * s, 18 * s, 18 * s); F('#f2e7a8'); } break; }
    case 'fountain': { ctx.beginPath(); ctx.ellipse(0, 0, 70 * s, 22 * s, 0, 0, 6.29); F('#b9b1b6'); ctx.beginPath(); ctx.ellipse(0, -2 * s, 58 * s, 16 * s, 0, 0, 6.29); F('#c9dde6'); ctx.fillStyle = '#b9b1b6'; ctx.fillRect(-5 * s, -44 * s, 10 * s, 44 * s); ctx.beginPath(); ctx.ellipse(0, -44 * s, 18 * s, 6 * s, 0, 0, 6.29); F('#b9b1b6'); ctx.strokeStyle = '#8fb8cc'; for (let k = 0; k < 5; k++) { ctx.beginPath(); ctx.moveTo(0, -46 * s); ctx.quadraticCurveTo((k - 2) * 14 * s, (-70 + Math.sin(t * 3 + k) * 4) * s, (k - 2) * 20 * s, -6 * s); ctx.stroke(); } dunked.forEach((l, k) => item(ctx, l.item, (k - 1) * 22 * s, -4 * s, s * 0.7)); break; }
    case 'pond': { ctx.beginPath(); ctx.ellipse(0, 0, 90 * s, 26 * s, 0, 0, 6.29); F('#c9dde6'); ctx.strokeStyle = 'rgba(255,255,255,0.6)'; ctx.beginPath(); ctx.ellipse(-20 * s, -4 * s, 30 * s, 6 * s, 0, 0, 6.29); ctx.stroke(); dunked.forEach((l, k) => item(ctx, l.item, (k - 1) * 24 * s, -2 * s, s * 0.7)); break; }
    case 'bench': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-26 * s, -16 * s, 52 * s, 5 * s); ctx.fillRect(-26 * s, -28 * s, 52 * s, 4 * s); ctx.fillRect(-22 * s, -11 * s, 4 * s, 11 * s); ctx.fillRect(18 * s, -11 * s, 4 * s, 11 * s); break; }
    case 'cafe': { ctx.beginPath(); ctx.rect(-70 * s, -60 * s, 140 * s, 8 * s); F('#c96a4a'); ctx.fillStyle = '#5b4f56'; ctx.fillRect(-66 * s, -52 * s, 3 * s, 52 * s); ctx.fillRect(63 * s, -52 * s, 3 * s, 52 * s); for (const tx of [-30, 30]) { ctx.beginPath(); ctx.ellipse(tx * s, -18 * s, 16 * s, 6 * s, 0, 0, 6.29); F('#ffffff'); ctx.fillStyle = '#5b4f56'; ctx.fillRect((tx - 1) * s, -18 * s, 2 * s, 18 * s); } break; }
    case 'stall': { ctx.beginPath(); ctx.rect(-50 * s, -34 * s, 100 * s, 34 * s); F('#c9b48a'); ctx.beginPath(); ctx.rect(-56 * s, -62 * s, 112 * s, 10 * s); F('#c96a4a'); ctx.fillStyle = '#5b4f56'; ctx.fillRect(-52 * s, -52 * s, 3 * s, 18 * s); ctx.fillRect(49 * s, -52 * s, 3 * s, 18 * s); for (let k = 0; k < 6; k++) { ctx.beginPath(); ctx.arc((-36 + k * 14) * s, -38 * s, 5 * s, 0, 6.29); F(['#e0602a', '#7cc47c', '#f2e7a8'][k % 3]); } break; }
    case 'garden': { ctx.beginPath(); ctx.rect(-60 * s, -14 * s, 120 * s, 14 * s); F('#8b6b4a'); for (let k = 0; k < 7; k++) { ctx.strokeStyle = '#6b8f5a'; ctx.beginPath(); ctx.moveTo((-50 + k * 16) * s, -14 * s); ctx.lineTo((-50 + k * 16) * s, -32 * s); ctx.stroke(); ctx.beginPath(); ctx.arc((-50 + k * 16) * s, -34 * s, 4 * s, 0, 6.29); F(['#ff2d55', '#ffcc00', '#af52de'][k % 3]); ctx.strokeStyle = '#3a2f36'; } break; }
    case 'booth': { ctx.beginPath(); ctx.rect(-16 * s, -70 * s, 32 * s, 70 * s); F('#c94a4a'); ctx.beginPath(); ctx.rect(-10 * s, -60 * s, 20 * s, 30 * s); F('#dfe9ee'); break; }
    case 'tree': { const h = (70 + r() * 30) * s; ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-4 * s, -h * 0.5, 8 * s, h * 0.5); ctx.beginPath(); ctx.ellipse(0, -h * 0.68, (30 + r() * 12) * s, h * 0.4, 0, 0, 6.29); F(`hsl(${95 + r() * 30} 35% ${38 + r() * 12}%)`); break; }
    case 'lamp': { ctx.fillStyle = '#3a2f36'; ctx.fillRect(-1.5 * s, -60 * s, 3 * s, 60 * s); ctx.beginPath(); ctx.rect(-6 * s, -70 * s, 12 * s, 12 * s); F('#f2e7a8'); break; }
  }
  ctx.restore();
}
/** 물건 낙서 */
function item(ctx: CanvasRenderingContext2D, it: ItemKey, x: number, y: number, s: number) {
  ctx.save(); ctx.translate(x, y); ctx.lineWidth = 1.4 * s; ctx.strokeStyle = '#3a2f36'; ctx.lineJoin = 'round';
  const F = (c: string) => { ctx.fillStyle = c; ctx.fill(); ctx.stroke(); };
  switch (it) {
    case 'hat': ctx.beginPath(); ctx.rect(-9 * s, -10 * s, 18 * s, 8 * s); F('#3a2f36'); ctx.beginPath(); ctx.rect(-14 * s, -3 * s, 28 * s, 3 * s); F('#3a2f36'); break;
    case 'phone': ctx.beginPath(); ctx.rect(-4 * s, -10 * s, 8 * s, 14 * s); F('#2b2b2b'); ctx.fillStyle = '#bfe0d4'; ctx.fillRect(-3 * s, -9 * s, 6 * s, 10 * s); break;
    case 'paper': ctx.beginPath(); ctx.rect(-8 * s, -10 * s, 16 * s, 12 * s); F('#ffffff'); ctx.beginPath(); for (let k = 0; k < 3; k++) { ctx.moveTo(-6 * s, (-7 + k * 3) * s); ctx.lineTo(6 * s, (-7 + k * 3) * s); } ctx.stroke(); break;
    case 'sandwich': ctx.beginPath(); ctx.moveTo(-9 * s, 0); ctx.lineTo(9 * s, 0); ctx.lineTo(0, -10 * s); ctx.closePath(); F('#e6d3a5'); break;
    case 'keys': ctx.beginPath(); ctx.arc(-4 * s, -4 * s, 4 * s, 0, 6.29); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-1 * s, -2 * s); ctx.lineTo(8 * s, 6 * s); ctx.stroke(); break;
    case 'glasses': ctx.beginPath(); ctx.arc(-5 * s, 0, 4 * s, 0, 6.29); ctx.moveTo(9 * s, 0); ctx.arc(5 * s, 0, 4 * s, 0, 6.29); ctx.stroke(); break;
    case 'broom': ctx.beginPath(); ctx.moveTo(0, -18 * s); ctx.lineTo(0, 4 * s); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-6 * s, 4 * s); ctx.lineTo(6 * s, 4 * s); ctx.lineTo(4 * s, 12 * s); ctx.lineTo(-4 * s, 12 * s); ctx.closePath(); F('#c9b48a'); break;
    case 'umbrella': ctx.beginPath(); ctx.arc(0, -4 * s, 10 * s, Math.PI, 0); F('#c94a4a'); ctx.beginPath(); ctx.moveTo(0, -4 * s); ctx.lineTo(0, 10 * s); ctx.stroke(); break;
    case 'cup': ctx.beginPath(); ctx.rect(-5 * s, -8 * s, 10 * s, 11 * s); F('#ffffff'); ctx.beginPath(); ctx.arc(7 * s, -3 * s, 3 * s, -1.5, 1.5); ctx.stroke(); break;
    case 'basket': ctx.beginPath(); ctx.moveTo(-10 * s, -6 * s); ctx.lineTo(10 * s, -6 * s); ctx.lineTo(7 * s, 6 * s); ctx.lineTo(-7 * s, 6 * s); ctx.closePath(); F('#c9b48a'); ctx.beginPath(); ctx.arc(0, -6 * s, 8 * s, Math.PI, 0); ctx.stroke(); break;
  }
  ctx.restore();
}
function actIcon(ctx: CanvasRenderingContext2D, act: Activity, x: number, y: number, s: number) {
  ctx.fillStyle = '#5b4f56'; ctx.font = `${10 * s}px ui-monospace, monospace`; ctx.textAlign = 'left';
  ctx.fillText({ read: 'reading', phone: 'on the phone', sit: 'sitting', water: 'watering', sweep: 'sweeping', shop: 'shopping', eat: 'eating', stand: '' }[act], x, y);
}
function name(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) { ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(text, x, y); }
function bubble(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) {
  ctx.font = `bold ${11 * s}px system-ui, sans-serif`; ctx.textAlign = 'left';
  const w = ctx.measureText(text).width + 14 * s, h = 20 * s; const bx = Math.min(ctx.canvas.width - w - 4, Math.max(4, x - w / 2)), by = y - 22 * s;
  ctx.fillStyle = '#ffffff'; ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1; ctx.beginPath(); ctx.roundRect(bx, by, w, h, 6 * s); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#1b0c15'; ctx.fillText(text, bx + 7 * s, by + 14 * s);
}
void spotOf;
