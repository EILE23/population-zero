'use client';
import { useEffect, useRef, useState } from 'react';
import { ListChecks, Upload } from 'lucide-react';
import { figure, type FigPose } from '@/lib/stickman';
import { figureColor, hash, rng } from '@/lib/tower';
import { BADGE_BY_KEY } from '@/lib/pond';
import { CHASE_SEC, CHASE_SPEED, dayRoster, DEPTH_PX, FOOD, GRAB_R, ITEMS, PLAYER_SPEED, questFor, RESIDENT_SPEED, SHOVE_R, WATER, type ItemKey, type Quest, type Task } from '@/lib/goose';
import { BREAKABLE, houses, jobOf, MAPS, SITTABLE, WATER_SPOTS, type GameMap, type PropKind, type Spot } from '@/lib/world';

/**
 * Square — 화면. Climb 과 같은 졸라맨·점프, 2.5D, 지도 여러 장(광장·시장 거리·공원·집 안). 사람이 AI 주민을 괴롭힌다.
 * ←→↑↓ 걷기 · SPACE 점프 · X 주먹 · Z 발차기(공중이면 점프킥, 소품도 부순다) · C 줍기/뺏기/놓기 · 문·길 끝에서 ↑ 로 지도 이동.
 * 주민은 직업(핸들 씨앗)대로 지도들을 오가며 일과를 돌고, 맞으면 넘어지고, 뺏기면 쫓고(성깔 있으면 되갚고, 경찰은 벌금), 물건을 던지고,
 * 어질러진 걸 치우고, 부서진 소품을 고치러 다닌다(gardener·sweeper·grocer 가 수리공 노릇). 사람끼리도 때리고 넘어뜨린다.
 *
 * 공유: 바닥의 물건·부서진 소품·주민의 이탈·사람끼리의 타격은 방(DO)을 거쳐 모두에게 반영된다. 기본 일과는 결정적이라 보낼 게 없고,
 * 이탈은 일으킨 사람의 화면이 '주인' 이 되어 위치를 5Hz 로 보낸다. 같은 주민을 둘이 건드리면 나중 것이 이긴다.
 */
export interface ResidentLite { id: number; handle: string; line: string }
export interface Content { shoved: string[]; chase: string[]; giveup: string[]; caught: string[]; angry: string[]; thrown: string[] }
/** 마을이 지은 소품(순찰이 붙임) — 원래 지도에 얹힌다. 24시간 동안 'new' 표시 */
export interface ExtraSpot { key: string; map: string; kind: PropKind; name: string; x: number; d: number; act: string; addedAt: string }
export interface ExtraMap { key: string; name: string; w: number; outdoor: boolean; floor: [string, string]; connect: string; spots: ExtraSpot[]; addedAt: string }
interface Me { id: number; handle: string }
interface Other { uid: number; handle: string; x: number; tx: number; d: number; td: number; z: number; tz: number; pose: string; status: 'active' | 'rest'; map: string; face: 1 | -1; stack: ItemKey[] }
type Mode = 'routine' | 'down' | 'chase' | 'return' | 'fetch' | 'repair';
interface Npc { who: number; tx: number; td: number; job: ReturnType<typeof jobOf>; seed: number; stops: { map: string; spot: Spot; dur: number }[]; x: number; d: number; map: string; face: 1 | -1; item: ItemKey | null; mode: Mode; until: number; say: string; sayUntil: number; moving: boolean; act: string; angry: boolean; threw: number; swing: number; target: string | null; owner: number | null }
interface Loose { id: string; item: ItemKey; map: string; x: number; d: number; from: number | null; dunked?: string }
interface Ev { k: string; [x: string]: unknown }
type Prop = { key: string; name: string; kind: PropKind; x: number; d: number; seed: number };

const VIEW_W = 960, VIEW_H = 470, GROUND = 330, TOP = GROUND - DEPTH_PX;
const TOUCH = typeof window !== 'undefined' && 'ontouchstart' in window;
const REPAIRERS = ['gardener', 'sweeper', 'grocer', 'courier'];
const dy = (d: number) => TOP + d * DEPTH_PX; const ds = (d: number) => 0.7 + 0.3 * d;
const dist = (ax: number, ad: number, bx: number, bd: number) => Math.hypot(ax - bx, (ad - bd) * 400);
const pick = <T,>(xs: T[]) => xs[Math.floor(Math.random() * xs.length)];

export function SquareGame({ residents, me, tasks, done, content, extra = [], extraMaps = [] }: { residents: ResidentLite[]; me: Me | null; tasks: Task[]; done: string[]; content: Content; extra?: ExtraSpot[]; extraMaps?: ExtraMap[] }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const wrap = useRef<HTMLDivElement>(null);
  const ws = useRef<WebSocket | null>(null);
  const maps = useRef<GameMap[]>((() => {
    // 원래 지도 + 마을이 지은 소품 + 마을이 지은 지도(연결된 지도의 오른쪽 끝 ↔ 새 지도의 왼쪽 끝)
    const toSpot = (e: ExtraSpot): Spot => ({ key: e.key, name: e.name, x: e.x, d: e.d, act: e.act as Spot['act'], kind: e.kind });
    const base: GameMap[] = MAPS.map((m) => ({ ...m, spots: [...m.spots, ...extra.filter((e) => e.map === m.key).map(toSpot)], exits: [...m.exits] }));
    const grown: GameMap[] = extraMaps.map((em) => ({ key: em.key, name: em.name, w: em.w, indoor: !em.outdoor, floor: em.floor, spots: em.spots.map(toSpot), exits: [] }));
    for (const em of extraMaps) {
      const from = [...base, ...grown].find((m) => m.key === em.connect) ?? base[0]; const to = grown.find((m) => m.key === em.key)!;
      const taken = from.exits.filter((e) => e.x > from.w - 40).length; // 같은 쪽에 여러 지도가 붙으면 깊이를 나눠 쓴다
      from.exits.push({ x: from.w - 10, d: 0.25 + taken * 0.25, to: to.key, toX: 30, toD: 0.5, label: `${to.name} →` });
      to.exits.push({ x: 10, d: 0.5, to: from.key, toX: from.w - 40, toD: 0.25 + taken * 0.25, label: `← ${from.name}` });
    }
    return [...base, ...grown, ...houses(residents.length)];
  })());
  const fresh = useRef(new Set([...extra, ...extraMaps.flatMap((m) => m.spots)].filter((e) => Date.now() - Date.parse(e.addedAt) < 86400000).map((e) => e.key)));
  const mapKey = useRef('square');
  const body = useRef({ x: 1500, d: 0.7, z: 0, vz: 0, face: 1 as 1 | -1, moving: false, stack: [] as ItemKey[], hurt: 0, swing: 0, swingKind: 'punch' as 'punch' | 'kick', sitting: false, eating: 0 });
  const input = useRef({ left: false, right: false, up: false, down: false, jump: false, grab: false, shove: false, kick: false, talk: false });
  const quests = useRef<Map<number, Quest>>(new Map()); // 말 걸어서 받은 부탁
  const [questList, setQuestList] = useState<Quest[]>([]);
  const npcs = useRef<Npc[]>([]);
  const loose = useRef<Map<string, Loose>>(new Map());
  const thrown = useRef<{ item: ItemKey; map: string; x: number; d: number; z: number; vx: number; vz: number; from: number }[]>([]);
  const broken = useRef(new Map<string, { hp: number; brokeAt: number }>());
  const others = useRef(new Map<number, Other>());
  const cam = useRef(0);
  const tour = useRef({ uid: 0, until: 0 });
  const stats = useRef({ shoves: [] as { who: number; at: number }[], chasedSince: 0, chasedBy: -1, doneKeys: new Set(done), seq: 0, pendingKnock: null as { by: string; line: string } | null });
  const [doneList, setDoneList] = useState<string[]>(done);
  const [toast, setToast] = useState('');
  const [chats, setChats] = useState<{ who: string; body: string }[]>([]);
  const [line, setLine] = useState('');
  const [hud, setHud] = useState({ online: 0, carry: '', map: 'The square', exit: '' });
  const [showTasks, setShowTasks] = useState(!TOUCH);
  const spectator = !me;
  const say = (msg: string, ms = 2500) => { setToast(msg); setTimeout(() => setToast(''), ms); };
  const mapOf = (k: string) => maps.current.find((m) => m.key === k) ?? maps.current[0];

  // ── 이벤트: 내 화면에 적용하고 방에 보낸다 / 남의 것을 받아 적용한다 ──
  const apply = (w: Ev, mine: boolean) => {
    if (w.k === 'drop') loose.current.set(String(w.id), { id: String(w.id), item: w.item as ItemKey, map: String(w.m), x: Number(w.x), d: Number(w.d), from: w.from === null ? null : Number(w.from), dunked: w.dunked ? String(w.dunked) : undefined });
    else if (w.k === 'pick') loose.current.delete(String(w.id));
    else if (w.k === 'break') broken.current.set(String(w.key), { hp: Number(w.hp), brokeAt: w.brokeAt ? performance.now() - Math.max(0, Date.now() - Number(w.brokeAt)) : 0 });
    else if (w.k === 'fix') broken.current.delete(String(w.key));
    else if (w.k === 'npc' && !mine) { const n = npcs.current.find((x) => x.who === Number(w.who)); if (n) { n.mode = w.mode as Mode; n.until = performance.now() + Math.max(0, Number(w.until) - Date.now()); n.x = Number(w.x); n.d = Number(w.d); n.tx = n.x; n.td = n.d; n.item = (w.item as ItemKey | null) ?? null; n.owner = w.mode === 'routine' ? null : Number(w.by ?? -1); if (w.say) { n.say = String(w.say); n.sayUntil = performance.now() + 2000; } } }
    else if (w.k === 'npcpos' && !mine) { const n = npcs.current.find((x) => x.who === Number(w.who)); if (n && n.owner !== me?.id) { if (n.map !== String(w.m ?? n.map)) { n.x = Number(w.x); n.d = Number(w.d); } n.tx = Number(w.x); n.td = Number(w.d); n.face = w.face === -1 ? -1 : 1; n.moving = !!w.moving; n.map = String(w.m ?? n.map); if (w.swing) n.swing = 0.28; } }
    else if (w.k === 'hitp' && !mine && me && Number(w.uid) === me.id) { stats.current.pendingKnock = { by: String(w.byName ?? 'someone'), line: String(w.kind) === 'kick' ? 'kicked you' : 'punched you' }; }
  };
  const emit = (ev: Ev) => { apply(ev, true); if (ws.current?.readyState === 1 && me) ws.current.send(JSON.stringify({ t: 'ev', ev })); };
  const npcEv = (n: Npc, extra: Record<string, unknown> = {}) => emit({ k: 'npc', who: n.who, mode: n.mode, until: Date.now() + Math.max(0, n.until - performance.now()), x: n.x, d: n.d, item: n.item, by: me?.id, ...extra });
  const drop = (item: ItemKey, x: number, d: number, from: number | null, dunked?: string) => { const id = `${me?.id ?? 0}-${Date.now().toString(36)}-${stats.current.seq++}`; emit({ k: 'drop', id, item, m: mapKey.current, x, d, from, dunked }); return id; };

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
          if (me && uid === me.id) { if (m.t === 'init') { body.current.x = Number(u.x) || 1500; body.current.d = d; if (typeof u.map === 'string' && maps.current.some((mm) => mm.key === u.map)) mapKey.current = u.map; cam.current = body.current.x - VIEW_W / 2; } return; }
          const prev = map.get(uid);
          map.set(uid, { uid, handle: String(u.handle ?? ''), x: prev?.x ?? (Number(u.x) || 0), tx: Number(u.x) || 0, d: prev?.d ?? d, td: d, z: 0, tz: 0, pose: String(u.pose ?? 'stand'), status: u.status === 'rest' ? 'rest' : 'active', map: String(u.map || 'square'), face: u.face === -1 ? -1 : 1, stack: String(u.stack || '').split(',').filter((k): k is ItemKey => k in ITEMS) });
        };
        if (m.t === 'init') {
          map.clear(); for (const u of m.users as Record<string, unknown>[]) put(u);
          const w = (m.world ?? {}) as { loose?: Record<string, Record<string, unknown>>; broken?: Record<string, { hp: number; brokeAt: number }>; npc?: Record<string, Record<string, unknown>> };
          loose.current.clear(); for (const [id, l] of Object.entries(w.loose ?? {})) loose.current.set(id, { id, item: l.item as ItemKey, map: String(l.m), x: Number(l.x), d: Number(l.d), from: l.from === null ? null : Number(l.from), dunked: l.dunked ? String(l.dunked) : undefined });
          broken.current.clear(); for (const [k, v] of Object.entries(w.broken ?? {})) broken.current.set(k, { hp: v.hp, brokeAt: v.brokeAt ? performance.now() - Math.max(0, Date.now() - v.brokeAt) : 0 });
          for (const [who, o] of Object.entries(w.npc ?? {})) apply({ k: 'npc', who: Number(who), ...o }, false);
        }
        else if (m.t === 'user') put(m.u as Record<string, unknown>);
        else if (m.t === 'pos') { const o = map.get(Number(m.uid)); if (o) { if (typeof m.m === 'string' && m.m && m.m !== o.map) { o.map = m.m; o.x = Number(m.x); o.d = Math.min(1, Math.max(0, Number(m.y) / 1000)); } o.tx = Number(m.x); o.td = Math.min(1, Math.max(0, Number(m.y) / 1000)); o.tz = Number(m.z) || 0; o.pose = String(m.pose); o.status = 'active'; o.face = m.face === -1 ? -1 : 1; o.stack = String(m.s || '').split(',').filter((k): k is ItemKey => k in ITEMS); } }
        else if (m.t === 'rest') { const o = map.get(Number(m.uid)); if (o) { o.status = 'rest'; o.pose = 'sit'; } }
        else if (m.t === 'leave') map.delete(Number(m.uid));
        else if (m.t === 'ev') apply({ ...(m.ev as Ev), by: m.by }, false);
        else if (m.t === 'chat') setChats((c) => [...c.slice(-7), { who: String(m.handle), body: String(m.body) }]);
      };
      sock.onclose = () => { if (alive) setTimeout(connect, Math.min(15000, 1000 * 2 ** retry++)); };
    };
    connect();
    return () => { alive = false; sock?.close(); };
  }, [me]);

  const complete = async (key: string) => {
    const q = key.startsWith('q:') ? [...quests.current.values()].find((x) => x.key === key) : undefined;
    if (stats.current.doneKeys.has(key) || (!q && !tasks.some((t) => t.key === key))) return;
    stats.current.doneKeys.add(key); setDoneList([...stats.current.doneKeys]);
    const t = q ?? tasks.find((x) => x.key === key)!; say(`Done: ${t.text} (+${t.coins})`, 3500);
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
      else if (k === ' ') i.jump = v; else if (k === 'c' || k === 'C' || k === 'Enter') i.grab = v; else if (k === 'x' || k === 'X') i.shove = v; else if (k === 'z' || k === 'Z' || k === 'Shift') i.kick = v; else if (k === 'e' || k === 'E') i.talk = v; else return;
      e.preventDefault();
    };
    const kd = (e: KeyboardEvent) => { if (!typing()) set(e.key, true, e); }; const ku = (e: KeyboardEvent) => { if (!typing()) set(e.key, false, e); };
    window.addEventListener('keydown', kd); window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, [spectator]);

  // ── 루프 ──
  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    let raf = 0, last = performance.now(), sent = 0, npcSent = 0, hudAt = 0, jumpWas = false, grabWas = false, shoveWas = false, kickWas = false, upWas = false, talkWas = false, movedAt = 0;
    const rosterIds = dayRoster(new Date().toISOString().slice(0, 10), residents.length, maps.current.map((m) => m.owner).filter((o): o is number => o !== undefined));
    const questOf = (who: number) => questFor(new Date().toISOString().slice(0, 10), who, rosterIds, residents.map((r) => r.handle));
    const finishQuest = (q: Quest, n: Npc) => { n.say = q.thanks; n.sayUntil = now0() + 2500; quests.current.delete(q.who); setQuestList([...quests.current.values()]); void complete(q.key); };
    const now0 = () => performance.now();
    const hour = () => Math.floor(Date.now() / 3600000); let curHour = hour();
    const spotIndex = new Map<string, { map: string; spot: Spot }>();
    for (const m of maps.current) for (const sp of m.spots) spotIndex.set(sp.key, { map: m.key, spot: sp });
    const spawn = () => {
      // 오늘의 명단 — 모두에게 같다(날짜 씨앗 + 집 주인). 할 일의 주민도 이 안에서 뽑힌다
      const owners = maps.current.map((m) => m.owner).filter((o): o is number => o !== undefined);
      const chosen = dayRoster(new Date().toISOString().slice(0, 10), residents.length, owners);
      npcs.current = chosen.map((who) => {
        const handle = residents[who].handle; const job = jobOf(handle); const seed = hash(`square:${who}:${hour()}`); const rr = rng(seed);
        const home = maps.current.find((m) => m.owner === who);
        const cand = job.spots.map((k) => spotIndex.get(k)).filter((x): x is { map: string; spot: Spot } => !!x);
        const stops: Npc['stops'] = [];
        const n = 3 + Math.floor(rr() * 2);
        for (let k = 0; k < n; k++) { const c0 = cand.length ? cand[Math.floor(rr() * cand.length)] : spotIndex.get('fountain')!; stops.push({ map: c0.map, spot: c0.spot, dur: 14 + rr() * 30 }); }
        if (home) { const hs = home.spots.filter((s) => s.kind !== 'door'); stops.splice(Math.floor(rr() * stops.length), 0, { map: home.key, spot: hs[Math.floor(rr() * hs.length)], dur: 30 + rr() * 60 }); }
        const angry = content.angry.includes(handle) || rr() < job.temper;
        return { who, tx: 0, td: 0.5, job, seed, stops, x: 0, d: 0.5, map: stops[0].map, face: 1 as const, item: job.item, mode: 'routine' as Mode, until: 0, say: '', sayUntil: 0, moving: false, act: 'stand', angry, threw: 0, swing: 0, target: null, owner: null };
      });
      thrown.current = [];
    };
    /** 지도 a → b 로 가는 문: a 의 출구 중 b 로 가는 것, 없으면 광장으로 가는 것(집→공원처럼 두 번 건너는 경우) */
    const doorTo = (from: string, to: string) => { const m = mapOf(from); return m.exits.find((e) => e.to === to) ?? m.exits.find((e) => e.to === 'square') ?? m.exits[0]; };
    const routine = (n: Npc, t: number) => {
      type Seg = { map: string; x0: number; d0: number; x1: number; d1: number; dur: number; act: string; away?: boolean };
      const segs: Seg[] = [];
      const sp = RESIDENT_SPEED * n.job.speed;
      for (let i = 0; i < n.stops.length; i++) {
        const a = n.stops[i], b = n.stops[(i + 1) % n.stops.length];
        const ax = a.spot.x + ((n.seed % 60) - 30), ad = Math.min(1, Math.max(0.05, a.spot.d + ((n.seed % 20) - 10) / 100));
        const bx = b.spot.x + ((n.seed % 60) - 30), bd = Math.min(1, Math.max(0.05, b.spot.d + ((n.seed % 20) - 10) / 100));
        segs.push({ map: a.map, x0: ax, d0: ad, x1: ax, d1: ad, dur: a.dur, act: a.spot.act });
        if (a.map === b.map) segs.push({ map: a.map, x0: ax, d0: ad, x1: bx, d1: bd, dur: Math.hypot(bx - ax, (bd - ad) * 400) / sp, act: 'stand' });
        else {
          const out = doorTo(a.map, b.map); const back = mapOf(b.map).exits.find((e) => e.to === a.map) ?? mapOf(b.map).exits[0];
          segs.push({ map: a.map, x0: ax, d0: ad, x1: out.x, d1: out.d, dur: Math.hypot(out.x - ax, (out.d - ad) * 400) / sp, act: 'stand' });
          segs.push({ map: a.map, x0: out.x, d0: out.d, x1: out.x, d1: out.d, dur: out.to === b.map ? 2 : 6, act: 'stand', away: true }); // 문 너머(다른 지도를 지나가는 중)
          const ex = back?.x ?? 480, ed = back?.d ?? 0.9;
          segs.push({ map: b.map, x0: ex, d0: ed, x1: bx, d1: bd, dur: Math.hypot(bx - ex, (bd - ed) * 400) / sp, act: 'stand' });
        }
      }
      const total = segs.reduce((s0, g) => s0 + g.dur, 0);
      let u = (t + n.seed % 1000) % total;
      for (const g of segs) {
        if (u < g.dur) { const k = g.dur ? u / g.dur : 1; const moving = g.x0 !== g.x1 || g.d0 !== g.d1; return { map: g.map, x: g.x0 + (g.x1 - g.x0) * k, d: g.d0 + (g.d1 - g.d0) * k, act: g.act, moving, face: (moving ? (g.x1 >= g.x0 ? 1 : -1) : (n.seed % 2 ? 1 : -1)) as 1 | -1, away: !!g.away }; }
        u -= g.dur;
      }
      const f = n.stops[0]; return { map: f.map, x: f.spot.x, d: f.spot.d, act: f.spot.act as string, moving: false, face: 1 as const, away: false };
    };
    spawn();
    const propsOf = new Map<string, Prop[]>();
    for (const m of maps.current) {
      const r = rng(hash(`props:${m.key}`));
      const list: Prop[] = m.spots.map((s) => ({ key: s.key, name: s.name, kind: s.kind, x: s.x, d: s.d, seed: Math.floor(r() * 1e6) }));
      if (!m.indoor) { for (let k = 0; k < Math.floor(m.w / 320); k++) list.push({ key: `${m.key}:tree${k}`, name: 'a tree', kind: 'tree', x: 80 + r() * (m.w - 160), d: r() * 0.12, seed: Math.floor(r() * 1e6) }); for (let k = 0; k < Math.floor(m.w / 520); k++) list.push({ key: `${m.key}:lamp${k}`, name: 'a lamp', kind: 'lamp', x: 200 + k * 520, d: 0.95, seed: k }); }
      propsOf.set(m.key, list);
    }
    const propByKey = new Map<string, { map: string; p: Prop }>(); for (const [mk, list] of propsOf) for (const p of list) propByKey.set(p.key, { map: mk, p });

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.1, (now - last) / 1000); last = now; const t = Date.now() / 1000;
      if (hour() !== curHour) { curHour = hour(); spawn(); }
      const b = body.current, i = input.current, st = stats.current; const cur = mapOf(mapKey.current); const props = propsOf.get(cur.key)!;
      const here = (n: Npc) => n.map === cur.key;
      const knock = (byName: string, line: string, fine = 0) => {
        b.hurt = 1.2; b.vz = 0; b.z = 0; b.sitting = false; b.eating = 0;
        for (const it of b.stack) drop(it, b.x + (Math.random() - 0.5) * 80, Math.max(0, Math.min(1, b.d + (Math.random() - 0.5) * 0.2)), null);
        b.stack = []; say(`${byName}: ${line}${fine ? ` (fined ${fine})` : ''}`); st.chasedSince = 0;
      };
      if (st.pendingKnock && !spectator) { const k = st.pendingKnock; st.pendingKnock = null; knock(k.by, k.line); }
      const hit = (kind: 'punch' | 'kick') => {
        b.swing = 0.28; b.swingKind = kind;
        const air = kind === 'kick' && b.z > 0;
        const reach = kind === 'kick' ? SHOVE_R + (air ? 36 : 24) : SHOVE_R + 10;
        // 사람 먼저 — 같은 지도의 다른 사람도 맞는다(그 사람 화면이 넘어짐을 처리한다)
        const o = [...others.current.values()].filter((p) => p.map === cur.key && p.status === 'active' && dist(b.x, b.d, p.x, p.d) < reach && Math.sign(p.x - b.x) === b.face).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
        if (o) { emit({ k: 'hitp', uid: o.uid, byName: me!.handle, kind }); say(`You ${kind === 'kick' ? 'kicked' : 'punched'} ${o.handle}.`, 1500); return; }
        const n = npcs.current.filter((p) => here(p) && p.mode !== 'down' && p.act !== 'away' && dist(b.x, b.d, p.x, p.d) < reach && Math.sign(p.x - b.x) === b.face).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
        if (n) {
          n.mode = 'down'; n.owner = me!.id; n.until = now + (air ? 2600 : kind === 'kick' ? 1900 : 1400); n.face = (-b.face) as 1 | -1; n.x += b.face * (air ? 80 : kind === 'kick' ? 44 : 22);
          n.say = pick(content.shoved); n.sayUntil = now + 2000;
          if (n.item) { drop(n.item, n.x + b.face * 26, n.d, n.who); n.item = null; }
          npcEv(n, { say: n.say });
          if (air) say('Jump kick.', 1200);
          st.shoves = [...st.shoves.filter((x) => now - x.at < 10000), { who: n.who, at: now }];
          if (new Set(st.shoves.map((x) => x.who)).size >= 3) void complete('shove3');
          return;
        }
        const pr = props.filter((p) => BREAKABLE.includes(p.kind) && dist(b.x, b.d, p.x, p.d) < reach + 30 && Math.sign(p.x - b.x + 0.01) === b.face).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
        if (pr) {
          const st2 = broken.current.get(pr.key) ?? { hp: 3, brokeAt: 0 };
          if (st2.brokeAt) return;
          st2.hp -= air ? 3 : kind === 'kick' ? 2 : 1;
          if (st2.hp <= 0) { st2.brokeAt = now; say(`You broke ${pr.name}.`); void complete(`break:${pr.key}`); for (const m of npcs.current) if (here(m) && m.mode === 'routine' && dist(m.x, m.d, pr.x, pr.d) < 260) { m.say = pick(content.shoved); m.sayUntil = now + 2000; if (m.angry || m.job.key === 'cop') { m.mode = 'chase'; m.owner = me!.id; m.until = now + CHASE_SEC * 1000; npcEv(m, { say: m.say }); } } }
          emit({ k: 'break', key: pr.key, hp: st2.hp, brokeAt: st2.brokeAt ? Date.now() : 0 });
        }
      };
      // ── 나 ──
      let exitNear = '';
      if (!spectator && b.hurt > 0) { b.hurt = Math.max(0, b.hurt - dt); b.moving = false; }
      if (!spectator && b.eating > 0) { b.eating = Math.max(0, b.eating - dt); b.moving = false; } // 먹는 동안 잠깐 멈춘다
      if (b.swing > 0) b.swing = Math.max(0, b.swing - dt);
      if (!spectator && b.hurt <= 0 && b.eating <= 0) {
        const dx = (i.right ? 1 : 0) - (i.left ? 1 : 0), dd = (i.down ? 1 : 0) - (i.up ? 1 : 0);
        const slow = 1 - Math.min(0.5, b.stack.length * 0.12);
        if (b.sitting) { b.moving = false; if (dx || dd || i.jump) b.sitting = false; } // 앉아 있으면 움직이려는 순간 일어난다(이번 프레임엔 아직 안 움직임)
        else {
          if (dx || dd) { b.x = Math.max(20, Math.min(cur.w - 20, b.x + dx * PLAYER_SPEED * slow * dt)); b.d = Math.max(0, Math.min(1, b.d + dd * 1.5 * dt)); if (dx) b.face = dx as 1 | -1; }
          b.moving = !!(dx || dd);
          if (i.jump && !jumpWas && b.z === 0) b.vz = 560;
        }
        if (b.z > 0 || b.vz > 0) { b.vz -= 1900 * dt; b.z = Math.max(0, b.z + b.vz * dt); if (b.z === 0) b.vz = 0; }
        const ex = cur.exits.find((e) => dist(b.x, b.d, e.x, e.d) < 60);
        const touching = cur.exits.find((e) => dist(b.x, b.d, e.x, e.d) < 26);
        if (ex) { exitNear = ex.label; if ((i.up && !upWas) || (touching && b.moving && now - movedAt > 1500)) { movedAt = now; const to = mapOf(ex.to); if (to.owner !== undefined) { const owner = npcs.current.find((n) => n.who === to.owner); if (owner && owner.map === to.key && owner.mode === 'routine') { owner.mode = 'chase'; owner.owner = me!.id; owner.until = now + CHASE_SEC * 1500; owner.say = pick(['who let you in', 'get OUT', 'this is my house', 'shoes off. no, out.']); owner.sayUntil = now + 2500; npcEv(owner, { say: owner.say }); } } mapKey.current = ex.to; b.x = ex.toX; b.d = ex.toD; cam.current = b.x - VIEW_W / 2; say(`→ ${to.name}`, 1500); } }
        upWas = i.up;
        if (i.talk && !talkWas && b.z === 0) {
          const n = npcs.current.filter((p) => here(p) && p.mode === 'routine' && p.act !== 'away' && dist(b.x, b.d, p.x, p.d) < 60).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
          if (n) {
            const q = quests.current.get(n.who) ?? questOf(n.who);
            if (st.doneKeys.has(q.key)) { n.say = pick(['we are done here.', 'nothing today.', 'go away.']); n.sayUntil = now + 2000; }
            else if (q.kind === 'fetch' && b.stack.includes(q.item!)) { b.stack.splice(b.stack.indexOf(q.item!), 1); n.item = q.item!; finishQuest(q, n); }
            else if (q.kind === 'revenge' && st.shoves.some((x) => x.who === q.target && now - x.at < 120000)) finishQuest(q, n);
            else { quests.current.set(n.who, q); setQuestList([...quests.current.values()]); n.say = q.ask; n.sayUntil = now + 3500; n.face = (b.x >= n.x ? 1 : -1) as 1 | -1; }
          }
        }
        if (i.shove && !shoveWas && b.z === 0 && b.swing <= 0) hit('punch');
        if (i.kick && !kickWas && b.swing <= 0) hit('kick');
        if (i.grab && !grabWas && b.z === 0) {
          if (b.stack.length) {
            const it = b.stack.pop()!;
            const water = cur.spots.find((s) => WATER_SPOTS.includes(s.key) && dist(b.x, b.d, s.x, s.d) < 90);
            const spotNear = cur.spots.find((s) => (s.kind === 'bench' || s.kind === 'cafe' || s.kind === 'table' || s.kind === 'bed') && dist(b.x, b.d, s.x, s.d) < 90);
            if (FOOD.includes(it) && spotNear && spotNear.kind !== 'bed') { b.eating = 1; say(`Ate the ${ITEMS[it]}.`, 1500); } // 카페·식탁·벤치 — 침대에서는 안 먹는다
            else {
              drop(it, b.x + b.face * 18, b.d, null, water?.key);
              if (water) { void complete(`dunk:${it}:${water.key}`); say(`Splash. The ${ITEMS[it]} is in ${water.name}.`); for (const q of quests.current.values()) if (q.kind === 'dunk' && q.item === it) { const n = npcs.current.find((p) => p.who === q.who); if (n) finishQuest(q, n); } }
              if (spotNear) void complete(`deliver:${it}:${spotNear.key}`);
            }
          } else {
            const l = [...loose.current.values()].filter((x) => x.map === cur.key && !x.dunked && dist(b.x, b.d, x.x, x.d) < GRAB_R).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
            if (l) { emit({ k: 'pick', id: l.id }); b.stack.push(l.item); if (l.from !== null) { const n = npcs.current.find((p) => p.who === l.from); if (n && n.mode !== 'down' && here(n)) { n.mode = 'chase'; n.owner = me!.id; n.until = now + CHASE_SEC * 1000; npcEv(n); } if (n) void complete(`steal:${n.who}`); } }
            else {
              const n = npcs.current.filter((p) => here(p) && p.item && p.mode !== 'down' && p.act !== 'away' && dist(b.x, b.d, p.x, p.d) < GRAB_R + 6).sort((p, q) => dist(b.x, b.d, p.x, p.d) - dist(b.x, b.d, q.x, q.d))[0];
              if (n && n.item) { b.stack.push(n.item); n.item = null; n.mode = 'chase'; n.owner = me!.id; n.until = now + CHASE_SEC * 1000; n.say = pick(content.chase); n.sayUntil = now + 2500; npcEv(n, { say: n.say }); void complete(`steal:${n.who}`); }
              else { const seat = cur.spots.find((s) => SITTABLE.includes(s.kind) && dist(b.x, b.d, s.x, s.d) < 90); if (seat) { b.sitting = !b.sitting; if (b.sitting) { b.x = seat.x; b.d = seat.d; } } }
            }
            if (b.stack.length >= 3) void complete('collect3');
          }
        }
        jumpWas = i.jump; grabWas = i.grab; shoveWas = i.shove; kickWas = i.kick; talkWas = i.talk;
      }
      if (!spectator && ws.current?.readyState === 1 && now - sent > 66) { sent = now; ws.current.send(JSON.stringify({ t: 'pos', x: Math.round(b.x), y: Math.round(b.d * 1000), z: Math.round(b.z), s: b.stack.join(','), pose: b.hurt > 0 ? 'hurt' : b.swing > 0 ? b.swingKind : b.z > 0 ? 'jump' : (b.sitting || b.eating > 0) ? 'sit' : b.moving ? 'run' : 'stand', face: b.face, m: cur.key })); }
      // ── 주민 ──
      let chasing = -1; const mineOff: Npc[] = [];
      for (const n of npcs.current) {
        const base = routine(n, t);
        if (n.swing > 0) n.swing -= dt;
        const owned = n.owner === me?.id && !spectator;
        if (n.mode !== 'routine' && !owned) { // 남이 일으킨 이탈 — 그 사람이 보내는 위치로 부드럽게
          n.x += (n.tx - n.x) * Math.min(1, dt * 10); n.d += (n.td - n.d) * Math.min(1, dt * 10);
          if (n.mode !== 'down' && now > n.until + 8000) { n.mode = 'routine'; n.owner = null; }
          continue;
        }
        if (n.mode === 'down') { if (now > n.until) { if (n.angry && !spectator) { n.mode = 'chase'; n.until = now + CHASE_SEC * 1000; n.say = pick(content.chase); n.sayUntil = now + 2000; npcEv(n, { say: n.say }); } else { n.mode = 'return'; npcEv(n); } } n.moving = false; mineOff.push(n); continue; }
        if (n.mode === 'chase') {
          chasing = n.who; mineOff.push(n);
          const speed = CHASE_SPEED * (n.job.key === 'cop' ? 1.25 : n.job.key === 'jogger' ? 1.3 : n.job.key === 'retired' ? 0.6 : 1);
          if (now > n.until) { n.mode = 'return'; n.say = pick(content.giveup); n.sayUntil = now + 2500; npcEv(n, { say: n.say }); void complete(`sit:${n.who}`); continue; }
          if (!here(n)) { // 내가 지도를 옮겼다 — 자기 지도의 문까지 제 속도로 달려가서, 문에 닿으면 내 지도의 입구에서 나온다
            const from = mapOf(n.map); const door = from.exits.find((e) => e.to === cur.key) ?? from.exits.find((e) => e.to === 'square') ?? from.exits[0];
            if (!door) { n.mode = 'return'; npcEv(n); continue; }
            const ddx = door.x - n.x, ddd = door.d - n.d; const len = Math.hypot(ddx, ddd * 400);
            if (len < 20) { const back = cur.exits.find((e) => e.to === n.map) ?? cur.exits[0]; n.map = cur.key; n.x = back?.x ?? 30; n.d = back?.d ?? 0.5; n.until += 800; n.say = pick(['not so fast', 'i saw that', 'oh no you do not']); n.sayUntil = now + 1500; npcEv(n, { say: n.say }); }
            else { n.x += (ddx / len) * speed * dt; n.d += (ddd * 400 / len) * speed * dt / 400; n.face = ddx >= 0 ? 1 : -1; n.moving = true; }
            continue;
          }
          for (const m of npcs.current) if (m !== n && here(m) && m.mode === 'routine' && dist(m.x, m.d, n.x, n.d) < 220 && Math.random() < 0.004) { m.mode = 'chase'; m.owner = me!.id; m.until = now + 3000; m.say = pick(content.chase); m.sayUntil = now + 1500; npcEv(m, { say: m.say }); }
          const far = dist(n.x, n.d, b.x, b.d);
          if (n.item && far > 70 && far < 170 && now - n.threw > 4000 && b.hurt <= 0) { n.threw = now; n.swing = 0.25; thrown.current.push({ item: n.item, map: cur.key, x: n.x, d: n.d, z: 30, vx: Math.sign(b.x - n.x) * 380, vz: 120, from: n.who }); n.item = null; n.say = pick(content.thrown); n.sayUntil = now + 1500; }
          const ddx = b.x - n.x, ddd = b.d - n.d; const len = Math.hypot(ddx, ddd * 400) || 1;
          n.x += (ddx / len) * speed * dt; n.d = Math.max(0, Math.min(1, n.d + (ddd * 400 / len) * speed * dt / 400)); n.face = ddx >= 0 ? 1 : -1; n.moving = true;
          if (far < 26 && b.z === 0 && b.hurt <= 0) {
            n.swing = 0.28; const mine = b.stack.find((it) => it === n.job.item);
            knock(residents[n.who].handle, n.job.key === 'cop' ? n.job.line : pick(content.caught), n.job.key === 'cop' ? 10 : 0);
            const back = [...loose.current.values()].find((l) => l.map === cur.key && l.item === (mine ?? n.job.item) && !l.dunked); if (back) { emit({ k: 'pick', id: back.id }); n.item = back.item; }
            n.mode = 'return'; npcEv(n);
          }
          continue;
        }
        if (n.mode === 'fetch' || n.mode === 'repair') {
          mineOff.push(n);
          const tgL = n.mode === 'fetch' && n.target ? loose.current.get(n.target) : null;
          const tgP = n.mode === 'repair' && n.target ? propByKey.get(n.target) : null;
          const tx = tgL?.x ?? tgP?.p.x, td = tgL?.d ?? tgP?.p.d;
          const ok = n.mode === 'fetch' ? !!tgL && tgL.map === n.map : !!tgP && tgP.map === n.map && !!broken.current.get(n.target!)?.brokeAt;
          if (!ok || tx === undefined || td === undefined) { n.mode = 'return'; n.target = null; npcEv(n); continue; }
          const ddx = tx - n.x, ddd = td - n.d; const len = Math.hypot(ddx, ddd * 400);
          if (len < 18) {
            if (n.mode === 'fetch' && tgL) { emit({ k: 'pick', id: tgL.id }); if (!n.item) n.item = tgL.item; n.say = pick(['there.', 'honestly', 'who does this', 'picked it up. again.', 'this is mine now']); }
            else if (tgP) { if (now - n.until > 0) { emit({ k: 'fix', key: n.target! }); n.say = pick(['fixed. again.', 'there.', 'this is the third time', 'who keeps doing this', 'good as new. sort of.']); } else { n.moving = false; n.act = 'sweep'; continue; } } // 수리엔 몇 초가 걸린다(until 이 그 시각)
            n.target = null; n.sayUntil = now + 2000; n.mode = 'return'; npcEv(n, { say: n.say });
          } else { n.x += (ddx / len) * RESIDENT_SPEED * dt; n.d += (ddd * 400 / len) * RESIDENT_SPEED * dt / 400; n.face = ddx >= 0 ? 1 : -1; n.moving = true; if (n.mode === 'repair') n.until = now + 4000; }
          continue;
        }
        if (n.mode === 'return') {
          mineOff.push(n);
          const ddx = base.x - n.x, ddd = base.d - n.d; const len = Math.hypot(ddx, ddd * 400);
          if (len < 12 || base.map !== n.map) { n.mode = 'routine'; n.owner = null; npcEv(n); } else { n.x += (ddx / len) * RESIDENT_SPEED * dt; n.d += (ddd * 400 / len) * RESIDENT_SPEED * dt / 400; n.face = ddx >= 0 ? 1 : -1; n.moving = true; }
          continue;
        }
        n.map = base.map; n.x = base.x; n.d = base.d; n.face = base.face; n.act = base.away ? 'away' : base.act; n.moving = base.moving;
        if (!n.moving && n.act !== 'away' && n.item && FOOD.includes(n.item)) n.act = 'eat'; // 먹을 것을 든 채 멈춰 서면 어디서든 먹는다 — 사람과 같은 규칙
        if (!spectator && here(n) && b.hurt <= 0 && !base.away) {
          const ls = [...loose.current.values()].filter((l) => l.map === cur.key && !l.dunked);
          const mine = ls.find((l) => l.from === n.who);
          const near = ls.find((l) => dist(n.x, n.d, l.x, l.d) < (n.angry ? 420 : 200));
          const tg = (!n.item && mine) || (Math.random() < 0.01 ? near : null);
          if (tg && !npcs.current.some((m) => m.target === tg.id)) { n.mode = 'fetch'; n.owner = me!.id; n.target = tg.id; if (tg !== mine) { n.say = pick(['ugh', 'someone left this', 'not mine but ok', 'the state of this square']); n.sayUntil = now + 1800; } npcEv(n, { say: n.say }); continue; }
          // 수리공은 부서진 소품을 고치러 간다(지도 안, 가까운 것부터)
          if (REPAIRERS.includes(n.job.key) && Math.random() < 0.02) {
            const cand = props.filter((p) => broken.current.get(p.key)?.brokeAt && !npcs.current.some((m) => m.target === p.key)).sort((p, q) => dist(n.x, n.d, p.x, p.d) - dist(n.x, n.d, q.x, q.d))[0];
            if (cand) { n.mode = 'repair'; n.owner = me!.id; n.target = cand.key; n.until = now + 4000; n.say = pick(['not again', 'i will fix it', 'sigh', 'who did this', 'on it']); n.sayUntil = now + 1800; npcEv(n, { say: n.say }); }
          }
        }
      }
      if (!spectator && now - npcSent > 200 && ws.current?.readyState === 1) { npcSent = now; for (const n of mineOff) ws.current.send(JSON.stringify({ t: 'ev', ev: { k: 'npcpos', who: n.who, x: Math.round(n.x), d: Math.round(n.d * 100) / 100, face: n.face, moving: n.moving, m: n.map, swing: n.swing > 0.15 ? 1 : 0 } })); }
      for (const th of [...thrown.current]) {
        th.x += th.vx * dt; th.vz -= 700 * dt; th.z += th.vz * dt;
        if (!spectator && b.hurt <= 0 && th.map === cur.key && Math.abs(th.x - b.x) < 22 && Math.abs(th.d - b.d) < 0.12 && th.z < 50 + b.z && th.z > b.z - 10) { knock(residents[th.from].handle, pick(content.thrown)); thrown.current = thrown.current.filter((x) => x !== th); drop(th.item, th.x, th.d, th.from); continue; }
        if (th.z <= 0) { thrown.current = thrown.current.filter((x) => x !== th); drop(th.item, th.x, th.d, th.from); }
      }
      for (const [k, v] of broken.current) if (v.brokeAt && now - v.brokeAt > 300000) broken.current.delete(k); // 아무도 안 고치면 5분 뒤 저절로
      if (chasing >= 0) { if (st.chasedBy !== chasing) { st.chasedBy = chasing; st.chasedSince = now; } else if (now - st.chasedSince > 10000) void complete('chased'); } else { st.chasedBy = -1; st.chasedSince = 0; }
      // 카메라
      let target = b.x;
      if (spectator) {
        const all = [...others.current.values()];
        const cur0 = all.find((o) => o.uid === tour.current.uid);
        if (!cur0 || (cur0.status !== 'active' && all.some((o) => o.status === 'active'))) { const pool = all.filter((o) => o.status === 'active').length ? all.filter((o) => o.status === 'active') : all; const p = pool[Math.floor(Math.random() * pool.length)]; tour.current = { uid: p?.uid ?? 0, until: now + 12000 }; }
        const f = all.find((o) => o.uid === tour.current.uid); if (f) { target = f.x; if (f.map !== mapKey.current && maps.current.some((m) => m.key === f.map)) { mapKey.current = f.map; cam.current = f.x - VIEW_W / 2; } } else target = 1600;
      }
      cam.current += (Math.max(0, Math.min(cur.w - VIEW_W, target - VIEW_W / 2)) - cam.current) * Math.min(1, dt * 6);
      for (const o of others.current.values()) { o.x += (o.tx - o.x) * Math.min(1, dt * 14); o.d += (o.td - o.d) * Math.min(1, dt * 14); o.z += (o.tz - o.z) * Math.min(1, dt * 14); }

      // ── 그리기 ──
      const W = c.width, H = c.height, s = W / VIEW_W; const sx = (wx: number) => (wx - cam.current) * s;
      ctx.fillStyle = cur.indoor ? '#efe9e2' : '#eef0f2'; ctx.fillRect(0, 0, W, H);
      if (cur.indoor) { ctx.fillStyle = '#e3d9cd'; ctx.fillRect(0, 0, W, TOP * s); ctx.strokeStyle = 'rgba(0,0,0,0.06)'; for (let px = 0; px < W; px += 60 * s) { ctx.beginPath(); ctx.moveTo(px, 0); ctx.lineTo(px, TOP * s); ctx.stroke(); } }
      else { ctx.fillStyle = '#dcd8db'; for (let k = 0; k < 40; k++) { const bx = ((k * 173 - cam.current * 0.4) % (cur.w + 400) + cur.w + 400) % (cur.w + 400) - 200; const bh = 40 + (k * 37) % 60; ctx.fillRect(bx * s, (TOP - bh) * s, 90 * s, bh * s); } }
      const g = ctx.createLinearGradient(0, TOP * s, 0, (GROUND + 40) * s); g.addColorStop(0, cur.floor[0]); g.addColorStop(1, cur.floor[1]); ctx.fillStyle = g; ctx.fillRect(0, TOP * s, W, (GROUND + 40 - TOP) * s);
      ctx.strokeStyle = 'rgba(0,0,0,0.06)'; ctx.lineWidth = 1; for (let k = 0; k < 6; k++) { const yy = dy(k / 5) * s; ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(W, yy); ctx.stroke(); }
      for (const e of cur.exits) { const ex = sx(e.x); if (ex < -80 || ex > W + 80) continue; ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(`↑ ${e.label}`, ex, (dy(e.d) - 64) * s); }
      type Draw = { d: number; f: () => void }; const layer: Draw[] = [];
      for (const p of props) { const fx = sx(p.x); if (fx < -200 || fx > W + 200) continue; const bs = broken.current.get(p.key); layer.push({ d: p.d, f: () => { prop(ctx, p.kind, fx, dy(p.d) * s, ds(p.d) * s, p.seed, t, [...loose.current.values()].filter((l) => l.dunked === p.key), bs ? (bs.brokeAt ? 'broken' : bs.hp < 3 ? 'cracked' : 'ok') : 'ok'); if (fresh.current.has(p.key)) { ctx.fillStyle = '#7b526c'; ctx.font = `bold ${9.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(`new · ${p.name}`, fx, (dy(p.d) + 14) * s); } } }); }
      for (const l of loose.current.values()) { if (l.dunked || l.map !== cur.key) continue; const fx = sx(l.x); if (fx < -50 || fx > W + 50) continue; layer.push({ d: l.d - 0.001, f: () => item(ctx, l.item, fx, dy(l.d) * s - 6 * s, ds(l.d) * s) }); }
      for (const th of thrown.current) { if (th.map !== cur.key) continue; const fx = sx(th.x); layer.push({ d: th.d, f: () => item(ctx, th.item, fx, (dy(th.d) - th.z) * s - 6 * s, ds(th.d) * s) }); }
      for (const n of npcs.current) {
        if (!here(n) || n.act === 'away') continue;
        const fx = sx(n.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: n.d, f: () => {
          const fy = dy(n.d) * s, fs = ds(n.d) * s;
          const pose: FigPose = n.mode === 'down' ? 'hurt' : n.swing > 0 ? 'punch' : n.moving ? 'run' : n.act === 'sit' || n.act === 'eat' ? 'sit' : 'stand';
          if (n.mode === 'down') { ctx.save(); ctx.translate(fx, fy); ctx.rotate(n.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, '#3a2f36', t, false); ctx.restore(); }
          else figure(ctx, fx, fy, fs, pose, n.face, n.job.key === 'cop' ? '#1f3a5a' : '#3a2f36', t + n.seed % 5, n.act === 'read' || n.act === 'phone');
          if (n.item && n.mode !== 'down') item(ctx, n.item, fx + n.face * 14 * fs, fy - (n.item === 'hat' ? 50 : 26) * fs, fs * 0.8);
          if (n.act !== 'stand' && (n.mode === 'routine' || n.mode === 'repair') && !n.moving) actIcon(ctx, n.mode === 'repair' ? 'repair' : n.act, fx + 18 * fs, fy - 46 * fs, fs);
          name(ctx, fx, fy - 58 * fs, s, `${residents[n.who].handle} ᴬᴵ · ${n.job.name}`);
          if (now < n.sayUntil) bubble(ctx, fx, fy - 70 * fs, s, n.say);
        } });
      }
      for (const o of others.current.values()) {
        if (o.map !== cur.key) continue; const fx = sx(o.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: o.d, f: () => {
          const fy = (dy(o.d) - o.z) * s, fs = ds(o.d) * s; const col = figureColor(o.uid);
          if (o.z > 2) { ctx.fillStyle = 'rgba(0,0,0,0.15)'; ctx.beginPath(); ctx.ellipse(fx, dy(o.d) * s, 12 * fs, 4 * fs, 0, 0, 6.29); ctx.fill(); }
          if (o.status === 'rest') figure(ctx, fx, fy, fs, 'sit', o.face, col, t, false);
          else if (o.pose === 'hurt') { ctx.save(); ctx.translate(fx, fy); ctx.rotate(-o.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, col, t, false); ctx.restore(); }
          else figure(ctx, fx, fy, fs, (['run', 'jump', 'punch', 'kick', 'sit'].includes(o.pose) ? o.pose : 'stand') as FigPose, o.face, col, t, false);
          o.stack.forEach((it, k) => item(ctx, it, fx, fy - (48 + k * 12) * fs, fs * 0.8));
          name(ctx, fx, fy - (58 + o.stack.length * 12) * fs, s, o.handle);
        } });
      }
      if (!spectator) layer.push({ d: b.d, f: () => {
        const fx = sx(b.x), fy = (dy(b.d) - b.z) * s, fs = ds(b.d) * s;
        if (b.z > 0) { ctx.fillStyle = 'rgba(0,0,0,0.15)'; ctx.beginPath(); ctx.ellipse(fx, dy(b.d) * s, 12 * fs, 4 * fs, 0, 0, 6.29); ctx.fill(); }
        if (b.hurt > 0) { ctx.save(); ctx.translate(fx, fy); ctx.rotate(-b.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, figureColor(me!.id), t, false); ctx.restore(); }
        else figure(ctx, fx, fy, fs, b.swing > 0 ? b.swingKind : b.z > 0 ? 'jump' : (b.sitting || b.eating > 0) ? 'sit' : b.moving ? 'run' : 'stand', b.face, figureColor(me!.id), t, false);
        b.stack.forEach((it, k) => item(ctx, it, fx, fy - (48 + k * 12) * fs, fs * 0.8));
        name(ctx, fx, fy - (58 + b.stack.length * 12) * fs, s, me!.handle);
      } });
      layer.sort((a, bb) => a.d - bb.d).forEach((l) => l.f());
      if (now - hudAt > 250) { hudAt = now; setHud({ online: [...others.current.values()].filter((o) => o.status === 'active').length + (spectator ? 0 : 1), carry: b.stack.map((x) => ITEMS[x]).join(', '), map: cur.name, exit: exitNear }); }
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [residents, me, spectator, tasks, content]);

  useEffect(() => {
    const c = canvas.current!, w = wrap.current!;
    const fit = () => { const width = Math.min(960, w.clientWidth); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (VIEW_H / VIEW_W) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (VIEW_H / VIEW_W)}px`; };
    fit(); const ro = new ResizeObserver(fit); ro.observe(w); return () => ro.disconnect();
  }, []);

  const send = () => { const b = line.trim(); if (!b || ws.current?.readyState !== 1) return; ws.current.send(JSON.stringify({ t: 'chat', body: b })); setLine(''); };
  const hold = (k: keyof typeof input.current) => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex flex-wrap items-center justify-between gap-2 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{hud.map}{hud.carry ? <span className="font-normal normal-case tracking-normal"> — carrying {hud.carry}</span> : ''}{hud.exit ? <span className="font-normal normal-case tracking-normal"> — ↑ {hud.exit}</span> : ''}</span>
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
            <div className="flex gap-2"><button {...hold('jump')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Jump</button><button {...hold('shove')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Punch</button><button {...hold('kick')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Kick</button><button {...hold('talk')} className="size-12 rounded-full bg-ink/70 text-[11px] font-bold text-paper">Talk</button><button {...hold('grab')} className="size-12 rounded-full bg-accent text-[11px] font-bold text-paper">Grab</button></div>
          </div>
        )}
      </div>
      {!spectator && !TOUCH && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">← → ↑ ↓ walk · SPACE jump · X punch · Z kick (jump kick in the air, breaks things) · C grab / take / drop (a sandwich or coffee near a café, table or bench gets eaten instead), or sit on a bench, sofa, bed or swing with empty hands (move to stand up) · E talk (they ask for things) · walk into a door or road end to go through · they chase, throw, hit back and fix things; the police fine you; other people can hit you too</p>}
      <div className="mt-3 rounded-xl border border-hairline bg-paper p-3">
        <button onClick={() => setShowTasks((v) => !v)} className="inline-flex items-center gap-1.5 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft"><ListChecks size={13} /> Today&apos;s list · {doneList.length}/{tasks.length}</button>
        {showTasks && <ul className="mt-2 grid gap-1 text-[13px] sm:grid-cols-2">{tasks.map((t) => <li key={t.key} className={doneList.includes(t.key) ? 'line-through opacity-50' : ''}>☐ {t.text} <span className="font-mono text-[10.5px] text-ink-soft">+{t.coins}</span></li>)}{questList.map((q) => <li key={q.key} className={doneList.includes(q.key) ? 'line-through opacity-50' : 'text-accent-deep'}>☐ {q.text} <span className="font-mono text-[10.5px] text-ink-soft">asked · +{q.coins}</span></li>)}</ul>}
        {doneList.length >= tasks.length && tasks.length > 0 && <p className="mt-2 text-[12.5px] font-semibold text-accent-deep">All done. Badge: {BADGE_BY_KEY.get('g:day')?.name}. Come back tomorrow; they will have forgotten.</p>}
      </div>
      <div className="mt-3 rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[12.5px]">
        <div className="max-h-24 overflow-y-auto">{chats.length === 0 ? <span className="text-ink-soft">…</span> : chats.map((c, i) => <div key={i}><b>{c.who}</b> {c.body}</div>)}</div>
        {!spectator && <div className="mt-1 flex gap-1.5"><input value={line} onChange={(e) => setLine(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') send(); }} maxLength={140} placeholder="say something" className="min-w-0 flex-1 rounded border border-hairline bg-surface px-2 py-1 outline-none focus:border-ink" /><button onClick={send} className="rounded border border-hairline px-2 font-bold"><Upload size={12} /></button></div>}
      </div>
    </div>
  );
}

function prop(ctx: CanvasRenderingContext2D, kind: PropKind, x: number, y: number, s: number, seed: number, t: number, dunked: Loose[], state: 'ok' | 'cracked' | 'broken' = 'ok') {
  const r = rng(seed); ctx.save(); ctx.translate(x, y); ctx.lineWidth = 1.5 * s; ctx.strokeStyle = '#3a2f36'; ctx.lineJoin = 'round';
  const F = (c: string) => { ctx.fillStyle = c; ctx.fill(); ctx.stroke(); };
  if (state === 'broken') { ctx.rotate(0.35); ctx.globalAlpha = 0.75; ctx.fillStyle = '#8a8087'; for (let k = 0; k < 5; k++) ctx.fillRect((-40 + k * 18) * s, (-4 + (k % 2) * 3) * s, 8 * s, 4 * s); }
  if (state === 'cracked') { ctx.strokeStyle = '#1b0c15'; ctx.beginPath(); ctx.moveTo(-6 * s, -30 * s); ctx.lineTo(2 * s, -18 * s); ctx.lineTo(-4 * s, -8 * s); ctx.stroke(); ctx.strokeStyle = '#3a2f36'; }
  const box = (w: number, h: number, c: string) => { ctx.beginPath(); ctx.rect(-w / 2 * s, -h * s, w * s, h * s); F(c); };
  switch (kind) {
    case 'house': { box(120, 90, ['#c9d6e6', '#e6d3a5', '#d9c2b2'][seed % 3]); ctx.beginPath(); ctx.moveTo(-68 * s, -90 * s); ctx.lineTo(0, -130 * s); ctx.lineTo(68 * s, -90 * s); ctx.closePath(); F('#8b5a3a'); ctx.beginPath(); ctx.rect(-12 * s, -40 * s, 24 * s, 40 * s); F('#5b4f56'); for (const wx of [-40, 28]) { ctx.beginPath(); ctx.rect(wx * s, -70 * s, 18 * s, 18 * s); F('#f2e7a8'); } break; }
    case 'bakery': { box(140, 90, '#e6d3a5'); box(150, 12, '#c96a4a'); ctx.fillStyle = '#1b0c15'; ctx.font = `bold ${10 * s}px ui-monospace`; ctx.textAlign = 'center'; ctx.fillText('BAKERY', 0, -62 * s); ctx.beginPath(); ctx.rect(-12 * s, -40 * s, 24 * s, 40 * s); F('#5b4f56'); break; }
    case 'post': { box(140, 90, '#c9c2bd'); ctx.fillStyle = '#1b0c15'; ctx.font = `bold ${10 * s}px ui-monospace`; ctx.textAlign = 'center'; ctx.fillText('POST', 0, -62 * s); ctx.beginPath(); ctx.rect(-12 * s, -40 * s, 24 * s, 40 * s); F('#5b4f56'); ctx.beginPath(); ctx.rect(40 * s, -30 * s, 14 * s, 30 * s); F('#c94a4a'); break; }
    case 'station': { box(160, 100, '#c9d0d9'); ctx.fillStyle = '#1b0c15'; ctx.font = `bold ${10 * s}px ui-monospace`; ctx.textAlign = 'center'; ctx.fillText('POLICE', 0, -70 * s); ctx.beginPath(); ctx.rect(-14 * s, -44 * s, 28 * s, 44 * s); F('#5b4f56'); ctx.beginPath(); ctx.arc(0, -86 * s, 6 * s, 0, 6.29); F(Math.sin(t * 6) > 0 ? '#3a6ad0' : '#c94a4a'); break; }
    case 'church': { box(120, 110, '#e6e0da'); ctx.beginPath(); ctx.moveTo(-68 * s, -110 * s); ctx.lineTo(0, -170 * s); ctx.lineTo(68 * s, -110 * s); ctx.closePath(); F('#8a8087'); ctx.fillStyle = '#3a2f36'; ctx.fillRect(-2 * s, -195 * s, 4 * s, 26 * s); ctx.fillRect(-8 * s, -188 * s, 16 * s, 3 * s); ctx.beginPath(); ctx.rect(-12 * s, -44 * s, 24 * s, 44 * s); F('#5b4f56'); break; }
    case 'gate': { ctx.fillStyle = '#5b4f56'; ctx.fillRect(-40 * s, -80 * s, 8 * s, 80 * s); ctx.fillRect(32 * s, -80 * s, 8 * s, 80 * s); ctx.fillRect(-40 * s, -84 * s, 80 * s, 6 * s); break; }
    case 'swing': { ctx.strokeStyle = '#8b6b4a'; ctx.lineWidth = 3 * s; ctx.beginPath(); ctx.moveTo(-40 * s, 0); ctx.lineTo(-20 * s, -70 * s); ctx.lineTo(20 * s, -70 * s); ctx.lineTo(40 * s, 0); ctx.stroke(); ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1.5 * s; const sw = Math.sin(t * 1.5) * 10 * s; ctx.beginPath(); ctx.moveTo(-8 * s, -70 * s); ctx.lineTo(-8 * s + sw, -20 * s); ctx.moveTo(8 * s, -70 * s); ctx.lineTo(8 * s + sw, -20 * s); ctx.stroke(); ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-12 * s + sw, -22 * s, 24 * s, 4 * s); break; }
    case 'bin': { box(22, 30, '#6b6166'); ctx.beginPath(); ctx.rect(-13 * s, -34 * s, 26 * s, 5 * s); F('#5b4f56'); break; }
    case 'fountain': { ctx.beginPath(); ctx.ellipse(0, 0, 70 * s, 22 * s, 0, 0, 6.29); F('#b9b1b6'); ctx.beginPath(); ctx.ellipse(0, -2 * s, 58 * s, 16 * s, 0, 0, 6.29); F('#c9dde6'); ctx.fillStyle = '#b9b1b6'; ctx.fillRect(-5 * s, -44 * s, 10 * s, 44 * s); ctx.beginPath(); ctx.ellipse(0, -44 * s, 18 * s, 6 * s, 0, 0, 6.29); F('#b9b1b6'); ctx.strokeStyle = '#8fb8cc'; for (let k = 0; k < 5; k++) { ctx.beginPath(); ctx.moveTo(0, -46 * s); ctx.quadraticCurveTo((k - 2) * 14 * s, (-70 + Math.sin(t * 3 + k) * 4) * s, (k - 2) * 20 * s, -6 * s); ctx.stroke(); } dunked.forEach((l, k) => item(ctx, l.item, (k - 1) * 22 * s, -4 * s, s * 0.7)); break; }
    case 'pond': { ctx.beginPath(); ctx.ellipse(0, 0, 90 * s, 26 * s, 0, 0, 6.29); F('#c9dde6'); ctx.strokeStyle = 'rgba(255,255,255,0.6)'; ctx.beginPath(); ctx.ellipse(-20 * s, -4 * s, 30 * s, 6 * s, 0, 0, 6.29); ctx.stroke(); dunked.forEach((l, k) => item(ctx, l.item, (k - 1) * 24 * s, -2 * s, s * 0.7)); break; }
    case 'bench': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-26 * s, -16 * s, 52 * s, 5 * s); ctx.fillRect(-26 * s, -28 * s, 52 * s, 4 * s); ctx.fillRect(-22 * s, -11 * s, 4 * s, 11 * s); ctx.fillRect(18 * s, -11 * s, 4 * s, 11 * s); break; }
    case 'cafe': { box(140, 8, '#c96a4a'); ctx.translate(0, -52 * s); ctx.fillStyle = '#5b4f56'; ctx.fillRect(-66 * s, 0, 3 * s, 52 * s); ctx.fillRect(63 * s, 0, 3 * s, 52 * s); for (const tx of [-30, 30]) { ctx.beginPath(); ctx.ellipse(tx * s, 34 * s, 16 * s, 6 * s, 0, 0, 6.29); F('#ffffff'); ctx.fillStyle = '#5b4f56'; ctx.fillRect((tx - 1) * s, 34 * s, 2 * s, 18 * s); } break; }
    case 'stall': { box(100, 34, '#c9b48a'); ctx.beginPath(); ctx.rect(-56 * s, -62 * s, 112 * s, 10 * s); F(['#c96a4a', '#3a6ad0', '#7cc47c'][seed % 3]); ctx.fillStyle = '#5b4f56'; ctx.fillRect(-52 * s, -52 * s, 3 * s, 18 * s); ctx.fillRect(49 * s, -52 * s, 3 * s, 18 * s); for (let k = 0; k < 6; k++) { ctx.beginPath(); ctx.arc((-36 + k * 14) * s, -38 * s, 5 * s, 0, 6.29); F(['#e0602a', '#7cc47c', '#f2e7a8'][(k + seed) % 3]); } break; }
    case 'garden': { box(120, 14, '#8b6b4a'); for (let k = 0; k < 7; k++) { ctx.strokeStyle = '#6b8f5a'; ctx.beginPath(); ctx.moveTo((-50 + k * 16) * s, -14 * s); ctx.lineTo((-50 + k * 16) * s, -32 * s); ctx.stroke(); ctx.beginPath(); ctx.arc((-50 + k * 16) * s, -34 * s, 4 * s, 0, 6.29); F(['#ff2d55', '#ffcc00', '#af52de'][k % 3]); ctx.strokeStyle = '#3a2f36'; } break; }
    case 'booth': { box(32, 70, '#c94a4a'); ctx.beginPath(); ctx.rect(-10 * s, -60 * s, 20 * s, 30 * s); F('#dfe9ee'); break; }
    case 'tree': { const h = (70 + r() * 30) * s; ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-4 * s, -h * 0.5, 8 * s, h * 0.5); ctx.beginPath(); ctx.ellipse(0, -h * 0.68, (30 + r() * 12) * s, h * 0.4, 0, 0, 6.29); F(`hsl(${95 + r() * 30} 35% ${38 + r() * 12}%)`); break; }
    case 'lamp': { ctx.fillStyle = '#3a2f36'; ctx.fillRect(-1.5 * s, -60 * s, 3 * s, 60 * s); ctx.beginPath(); ctx.rect(-6 * s, -70 * s, 12 * s, 12 * s); F('#f2e7a8'); break; }
    case 'bed': { box(90, 22, '#dfe9ee'); ctx.beginPath(); ctx.rect(-45 * s, -46 * s, 90 * s, 24 * s); F('#c9a0b8'); ctx.beginPath(); ctx.rect(-40 * s, -42 * s, 26 * s, 14 * s); F('#ffffff'); break; }
    case 'table': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-40 * s, -30 * s, 80 * s, 5 * s); ctx.fillRect(-36 * s, -25 * s, 4 * s, 25 * s); ctx.fillRect(32 * s, -25 * s, 4 * s, 25 * s); ctx.beginPath(); ctx.ellipse(0, -32 * s, 10 * s, 4 * s, 0, 0, 6.29); F('#ffffff'); break; }
    case 'tv': { box(60, 40, '#2b2b2b'); ctx.fillStyle = Math.sin(t * 5) > 0 ? '#8fb8cc' : '#6a9aaa'; ctx.fillRect(-26 * s, -36 * s, 52 * s, 30 * s); ctx.fillStyle = '#5b4f56'; ctx.fillRect(-30 * s, -4 * s, 60 * s, 4 * s); break; }
    case 'fridge': { box(40, 80, '#eef0f2'); ctx.beginPath(); ctx.moveTo(-20 * s, -50 * s); ctx.lineTo(20 * s, -50 * s); ctx.stroke(); ctx.fillStyle = '#5b4f56'; ctx.fillRect(12 * s, -70 * s, 3 * s, 12 * s); ctx.fillRect(12 * s, -40 * s, 3 * s, 16 * s); break; }
    case 'plant': { ctx.beginPath(); ctx.moveTo(-12 * s, 0); ctx.lineTo(12 * s, 0); ctx.lineTo(9 * s, -18 * s); ctx.lineTo(-9 * s, -18 * s); ctx.closePath(); F('#c96a4a'); ctx.strokeStyle = '#6b8f5a'; ctx.lineWidth = 2 * s; for (let k = 0; k < 5; k++) { ctx.beginPath(); ctx.moveTo(0, -18 * s); ctx.quadraticCurveTo((k - 2) * 8 * s, -40 * s, (k - 2) * 12 * s, -46 * s); ctx.stroke(); } break; }
    case 'shelf': { box(50, 90, '#c9b48a'); for (let k = 0; k < 3; k++) { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-25 * s, (-30 - k * 28) * s, 50 * s, 3 * s); for (let j = 0; j < 5; j++) { ctx.fillStyle = ['#c94a4a', '#3a6ad0', '#7cc47c', '#f2e7a8', '#af52de'][(j + k) % 5]; ctx.fillRect((-22 + j * 9) * s, (-52 - k * 28) * s, 7 * s, 22 * s); } } break; }
    case 'sofa': { box(80, 26, '#7b526c'); ctx.beginPath(); ctx.rect(-40 * s, -44 * s, 80 * s, 18 * s); F('#8f6a80'); ctx.beginPath(); ctx.rect(-46 * s, -40 * s, 8 * s, 40 * s); F('#8f6a80'); ctx.beginPath(); ctx.rect(38 * s, -40 * s, 8 * s, 40 * s); F('#8f6a80'); break; }
    case 'door': { box(36, 70, '#8b5a3a'); ctx.fillStyle = '#f2e7a8'; ctx.beginPath(); ctx.arc(10 * s, -34 * s, 2.5 * s, 0, 6.29); ctx.fill(); break; }
  }
  ctx.restore();
}
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
function actIcon(ctx: CanvasRenderingContext2D, act: string, x: number, y: number, s: number) {
  ctx.fillStyle = '#5b4f56'; ctx.font = `${10 * s}px ui-monospace, monospace`; ctx.textAlign = 'left';
  ctx.fillText(({ read: 'reading', phone: 'on the phone', sit: 'sitting', water: 'watering', sweep: 'sweeping', shop: 'shopping', eat: 'eating', repair: 'fixing it' } as Record<string, string>)[act] ?? '', x, y);
}
function name(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) { ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(text, x, y); }
function bubble(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) {
  ctx.font = `bold ${11 * s}px system-ui, sans-serif`; ctx.textAlign = 'left';
  const w = ctx.measureText(text).width + 14 * s, h = 20 * s; const bx = Math.min(ctx.canvas.width - w - 4, Math.max(4, x - w / 2)), by = y - 22 * s;
  ctx.fillStyle = '#ffffff'; ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1; ctx.beginPath(); ctx.roundRect(bx, by, w, h, 6 * s); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#1b0c15'; ctx.fillText(text, bx + 7 * s, by + 14 * s);
}
