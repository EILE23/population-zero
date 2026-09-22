'use client';
import { useEffect, useRef, useState } from 'react';
import { ListChecks, Upload } from 'lucide-react';
import { critter, figure, SEATED, type CritterPose, type FigPose } from '@/lib/stickman';
import { figureColor, hash, rng } from '@/lib/tower';
import { BADGE_BY_KEY, ITEM_LIST as POND_ITEMS } from '@/lib/pond';
import { CHASE_SEC, CHASE_SPEED, dayRoster, DEPTH_PX, FOOD, GRAB_R, ITEMS, PLAYER_SPEED, questFor, RESIDENT_SPEED, SHOVE_R, WATER, WEARABLE, type ItemKey, type Quest, type Task } from '@/lib/goose';
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
interface Other { uid: number; handle: string; x: number; tx: number; d: number; td: number; z: number; tz: number; pose: string; status: 'active' | 'rest'; map: string; face: 1 | -1; stack: ItemKey[]; worn: Set<ItemKey> }
/** 걸친 것의 몸 위 표시 위치(발끝 기준 y, px) — 모자는 머리 위, 안경은 얼굴 높이. 목록에 없으면 걸칠 수 없는 것 */
const WORN_Y: Partial<Record<ItemKey, number>> = { hat: 50, glasses: 40 };
/** pos.s 문자열 파싱 — 걸친 것은 `hat!` 처럼 느낌표가 붙어 온다(룸은 그대로 중계하므로 서버 쪽 변경이 필요 없다) */
const parseStack = (raw: string): { stack: ItemKey[]; worn: Set<ItemKey> } => {
  const stack: ItemKey[] = []; const worn = new Set<ItemKey>();
  for (const tok of raw.split(',')) { const w = tok.endsWith('!'); const k = (w ? tok.slice(0, -1) : tok) as ItemKey; if (k in ITEMS) { stack.push(k); if (w) worn.add(k); } }
  return { stack, worn };
};
type Mode = 'routine' | 'down' | 'chase' | 'return' | 'fetch' | 'repair' | 'trip';
interface Npc { who: number; tx: number; td: number; swingKind?: 'punch' | 'throw'; job: ReturnType<typeof jobOf>; seed: number; stops: { map: string; spot: Spot; dur: number }[]; x: number; d: number; map: string; face: 1 | -1; item: ItemKey | null; mode: Mode; until: number; tripUntil: number; say: string; sayUntil: number; moving: boolean; act: string; angry: boolean; threw: number; swing: number; target: string | null; owner: number | null }
interface Loose { id: string; item: ItemKey; map: string; x: number; d: number; from: number | null; dunked?: string }
interface Ev { k: string; [x: string]: unknown }
type Prop = { key: string; name: string; kind: PropKind; x: number; d: number; seed: number };

const VIEW_W = 960, VIEW_H = 470, GROUND = 330, TOP = GROUND - DEPTH_PX;
const TOUCH = typeof window !== 'undefined' && 'ontouchstart' in window;
const REPAIRERS = ['gardener', 'sweeper', 'grocer', 'courier'];
const dy = (d: number) => TOP + d * DEPTH_PX; const ds = (d: number) => 0.7 + 0.3 * d;
const dist = (ax: number, ad: number, bx: number, bd: number) => Math.hypot(ax - bx, (ad - bd) * 400);
const pick = <T,>(xs: T[]) => xs[Math.floor(Math.random() * xs.length)];
/** 자리마다 다른 앉는 자세 — 침대는 눕고, 그네는 그네를 타고, 나머지는 앉는다. 소파·침대는 자리 높이만큼 몸을 띄운다 */
const seatPose = (kind: PropKind | undefined): FigPose => kind === 'bed' ? 'sit' : kind === 'swing' ? 'swing' : 'seat';
const SEAT_LIFT: Partial<Record<PropKind, number>> = { sofa: 10, bed: 20 };
const seatAt = (m: GameMap, x: number, d: number) => m.spots.find((s) => SITTABLE.includes(s.kind) && dist(x, d, s.x, s.d) < 40);
/** 주민 일과 → 자세. 사람이 같은 걸 할 때도 같은 자세를 쓴다 */
const actPose = (act: string, seat: PropKind | undefined): FigPose => act === 'sit' ? seatPose(seat) : act === 'eat' ? (seat ? 'eat' : 'chew') : (({ read: 'read', phone: 'phone', water: 'water', sweep: 'sweep', shop: 'shop', pushup: 'pushup', pullup: 'pullup', press: 'press', watch: 'watch', fish: 'fish', feed: 'feed' } as Record<string, FigPose>)[act] ?? 'stand');
const KNOWN_POSES = ['run', 'jump', 'punch', 'kick', 'sit', 'seat', 'swing', 'eat', 'chew', 'read', 'phone', 'water', 'sweep', 'fix', 'shop', 'pushup', 'pullup', 'press', 'throw', 'watch', 'trip', 'fish'];
interface Duck { map: string; pond: string; baseX: number; baseD: number; seed: number; x: number; d: number; scareUntil: number }

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
  const body = useRef({ x: 1500, d: 0.7, z: 0, vz: 0, face: 1 as 1 | -1, moving: false, stack: [] as ItemKey[], wearing: new Set<ItemKey>(), hurt: 0, swing: 0, swingKind: 'punch' as 'punch' | 'kick' | 'throw', sitting: false, eating: 0, seat: 'bench' as PropKind, exercise: 0, exerciseKind: 'press' as 'pushup' | 'pullup' | 'press', still: null as 'tv' | 'shelf' | null, watering: 0, tripped: 0, fishing: 0, feeding: 0 });
  const input = useRef({ left: false, right: false, up: false, down: false, jump: false, grab: false, shove: false, kick: false, talk: false });
  const quests = useRef<Map<number, Quest>>(new Map()); // 말 걸어서 받은 부탁
  const feedRef = useRef({ map: '', x: 0, d: 0, until: 0 }); // 마지막으로 오리에게 모이를 준 곳(나 또는 근처 주민) — 오리가 그쪽으로 모인다
  const [questList, setQuestList] = useState<Quest[]>([]);
  const npcs = useRef<Npc[]>([]);
  const loose = useRef<Map<string, Loose>>(new Map());
  /** 날아가는 물건 — from: 던진 주민(사람이 던졌으면 -1), by: 던진 사람 uid, remote: 남의 화면에서 온 복사본(그림만, 판정·낙하물은 던진 쪽이 낸다) */
  const thrown = useRef<{ item: ItemKey; map: string; x: number; d: number; z: number; vx: number; vz: number; from: number; by?: number; remote?: boolean }[]>([]);
  const broken = useRef(new Map<string, { hp: number; brokeAt: number }>());
  const others = useRef(new Map<number, Other>());
  const said = useRef(new Map<number, { body: string; until: number }>()); // 채팅 말풍선 — uid → 말, 4초. 아래 목록에도 남는다
  const cam = useRef(0);
  const tour = useRef({ uid: 0, until: 0 });
  const stats = useRef({ shoves: [] as { who: number; at: number }[], chasedSince: 0, chasedBy: -1, doneKeys: new Set(done), seq: 0, pendingKnock: null as { by: string; line: string } | null });
  const [doneList, setDoneList] = useState<string[]>(done);
  const [toast, setToast] = useState('');
  // 방의 init(저장된 내 자리·지도)이 오기 전엔 내 캐릭터를 그리지도 보내지도 않는다 — 기본 좌표에 잠깐 서 있는 게 보였다(운영자 2026-09-22). 4초 안에 안 오면(방이 죽었을 때) 그냥 시작
  const ready = useRef(false); const [loading, setLoading] = useState(true);
  const [chats, setChats] = useState<{ who: string; body: string }[]>([]);
  const [line, setLine] = useState('');
  const [hud, setHud] = useState({ online: 0, carry: '', map: 'The square', exit: '' });
  const [showTasks, setShowTasks] = useState(!TOUCH);
  const spectator = !me;
  const say = (msg: string, ms = 2500) => { setToast(msg); setTimeout(() => setToast(''), ms); };
  const mapOf = (k: string) => maps.current.find((m) => m.key === k) ?? maps.current[0];
  /** 방(서버) 시각 — 주민 일과는 (씨앗, 시각) 의 함수라 모두가 같은 시계를 써야 같은 자리에 보인다. init 의 now 로 내 시계와의 차이를 잰다 */
  const skew = useRef(0); const wall = () => Date.now() + skew.current;

  // ── 이벤트: 내 화면에 적용하고 방에 보낸다 / 남의 것을 받아 적용한다 ──
  const apply = (w: Ev, mine: boolean) => {
    if (w.k === 'drop') loose.current.set(String(w.id), { id: String(w.id), item: w.item as ItemKey, map: String(w.m), x: Number(w.x), d: Number(w.d), from: w.from === null ? null : Number(w.from), dunked: w.dunked ? String(w.dunked) : undefined });
    else if (w.k === 'pick') loose.current.delete(String(w.id));
    else if (w.k === 'break') broken.current.set(String(w.key), { hp: Number(w.hp), brokeAt: w.brokeAt ? performance.now() - Math.max(0, wall() - Number(w.brokeAt)) : 0 });
    else if (w.k === 'fix') broken.current.delete(String(w.key));
    else if (w.k === 'npc' && !mine) { const n = npcs.current.find((x) => x.who === Number(w.who)); if (n) { n.mode = w.mode as Mode; n.until = performance.now() + Math.max(0, Number(w.until) - wall()); n.x = Number(w.x); n.d = Number(w.d); n.tx = n.x; n.td = n.d; n.item = (w.item as ItemKey | null) ?? null; n.owner = w.mode === 'routine' ? null : Number(w.by ?? -1); if (w.say) { n.say = String(w.say); n.sayUntil = performance.now() + 2000; } } }
    else if (w.k === 'npcpos' && !mine) { const n = npcs.current.find((x) => x.who === Number(w.who)); if (n && n.owner !== me?.id) { if (n.map !== String(w.m ?? n.map)) { n.x = Number(w.x); n.d = Number(w.d); } n.tx = Number(w.x); n.td = Number(w.d); n.face = w.face === -1 ? -1 : 1; n.moving = !!w.moving; n.map = String(w.m ?? n.map); if (w.swing) { n.swing = 0.28; n.swingKind = w.sk === 'throw' ? 'throw' : 'punch'; } } }
    else if (w.k === 'hitp' && !mine && me && Number(w.uid) === me.id) { stats.current.pendingKnock = { by: String(w.byName ?? 'someone'), line: String(w.kind) === 'kick' ? 'kicked you' : String(w.kind) === 'throw' ? `threw ${ITEMS[w.item as ItemKey] ? `a ${ITEMS[w.item as ItemKey]}` : 'something'} at you` : 'punched you' }; }
    else if (w.k === 'throw' && !mine) thrown.current.push({ item: w.item as ItemKey, map: String(w.m), x: Number(w.x), d: Number(w.d), z: Number(w.z), vx: Number(w.vx), vz: Number(w.vz), from: Number(w.from ?? -1), by: Number(w.by ?? 0), remote: true }); // 남이 던진 것 — 궤적만 그린다, 판정·떨어진 물건은 던진 쪽이 낸다
  };
  const emit = (ev: Ev) => { apply(ev, true); if (ws.current?.readyState === 1 && me) ws.current.send(JSON.stringify({ t: 'ev', ev })); };
  const npcEv = (n: Npc, extra: Record<string, unknown> = {}) => emit({ k: 'npc', who: n.who, mode: n.mode, until: wall() + Math.max(0, n.until - performance.now()), x: n.x, d: n.d, item: n.item, by: me?.id, ...extra });
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
          const prev = map.get(uid); const { stack, worn } = parseStack(String(u.stack || ''));
          map.set(uid, { uid, handle: String(u.handle ?? ''), x: prev?.x ?? (Number(u.x) || 0), tx: Number(u.x) || 0, d: prev?.d ?? d, td: d, z: 0, tz: 0, pose: String(u.pose ?? 'stand'), status: u.status === 'rest' ? 'rest' : 'active', map: String(u.map || 'square'), face: u.face === -1 ? -1 : 1, stack, worn });
        };
        if (m.t === 'init') {
          if (typeof m.now === 'number' && Math.abs(m.now - Date.now()) < 6 * 3600000) skew.current = m.now - Date.now(); // 반나절 넘게 어긋나면 서버 쪽이 이상한 것
          map.clear(); for (const u of m.users as Record<string, unknown>[]) put(u);
          const w = (m.world ?? {}) as { loose?: Record<string, Record<string, unknown>>; broken?: Record<string, { hp: number; brokeAt: number }>; npc?: Record<string, Record<string, unknown>> };
          loose.current.clear(); for (const [id, l] of Object.entries(w.loose ?? {})) loose.current.set(id, { id, item: l.item as ItemKey, map: String(l.m), x: Number(l.x), d: Number(l.d), from: l.from === null ? null : Number(l.from), dunked: l.dunked ? String(l.dunked) : undefined });
          broken.current.clear(); for (const [k, v] of Object.entries(w.broken ?? {})) broken.current.set(k, { hp: v.hp, brokeAt: v.brokeAt ? performance.now() - Math.max(0, wall() - v.brokeAt) : 0 });
          for (const [who, o] of Object.entries(w.npc ?? {})) apply({ k: 'npc', who: Number(who), ...o }, false);
          if (!ready.current) { ready.current = true; setLoading(false); }
        }
        else if (m.t === 'user') put(m.u as Record<string, unknown>);
        else if (m.t === 'pos') { const o = map.get(Number(m.uid)); if (o) { if (typeof m.m === 'string' && m.m && m.m !== o.map) { o.map = m.m; o.x = Number(m.x); o.d = Math.min(1, Math.max(0, Number(m.y) / 1000)); } o.tx = Number(m.x); o.td = Math.min(1, Math.max(0, Number(m.y) / 1000)); o.tz = Number(m.z) || 0; o.pose = String(m.pose); o.status = 'active'; o.face = m.face === -1 ? -1 : 1; const { stack, worn } = parseStack(String(m.s || '')); o.stack = stack; o.worn = worn; } }
        else if (m.t === 'rest') { const o = map.get(Number(m.uid)); if (o) { o.status = 'rest'; o.pose = 'sit'; } }
        else if (m.t === 'leave') map.delete(Number(m.uid));
        else if (m.t === 'ev') apply({ ...(m.ev as Ev), by: m.by }, false);
        else if (m.t === 'chat') { setChats((c) => [...c.slice(-7), { who: String(m.handle), body: String(m.body) }]); if (Number(m.uid)) said.current.set(Number(m.uid), { body: String(m.body), until: performance.now() + 4000 }); }
      };
      sock.onclose = () => { if (alive) setTimeout(connect, Math.min(15000, 1000 * 2 ** retry++)); };
    };
    connect();
    const fallback = setTimeout(() => { if (!ready.current) { ready.current = true; setLoading(false); } }, 4000);
    return () => { alive = false; clearTimeout(fallback); sock?.close(); };
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
      // 화살표만 — WASD 는 뺐다(운영자 2026-09-22: 채팅·다른 키와 겹쳐 불편)
      if (k === 'ArrowLeft') i.left = v; else if (k === 'ArrowRight') i.right = v;
      else if (k === 'ArrowUp') i.up = v; else if (k === 'ArrowDown') i.down = v;
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
    const hour = () => Math.floor(wall() / 3600000); let curHour = hour();
    const spotIndex = new Map<string, { map: string; spot: Spot }>();
    for (const m of maps.current) for (const sp of m.spots) spotIndex.set(sp.key, { map: m.key, spot: sp });
    const spawn = () => {
      // 오늘의 명단 — 모두에게 같다(날짜 씨앗 + 집 주인). 할 일의 주민도 이 안에서 뽑힌다
      const owners = maps.current.map((m) => m.owner).filter((o): o is number => o !== undefined);
      const chosen = dayRoster(new Date().toISOString().slice(0, 10), residents.length, owners);
      const used = new Map<string, number>(); // 자리별 배정 수 — 같은 직업이 한 곳에 몰리지 않게 덜 쓰인 자리부터 준다
      npcs.current = chosen.map((who) => {
        const handle = residents[who].handle; const job = jobOf(handle); const seed = hash(`square:${who}:${hour()}`); const rr = rng(seed);
        const home = maps.current.find((m) => m.owner === who);
        // 직업표의 자리 이름이 지도 이름(square·street·park…)이면 "그 지도의 빈 데 아무 곳" — 산책 정거장. 예전엔 자리가 아니라며 버려져 개 산책·청소부·경찰이 남은 한두 자리에 몰렸다
        const wander = (mapKeyName: string, k: number): { map: string; spot: Spot } | null => {
          const m = maps.current.find((mm) => mm.key === mapKeyName && !mm.indoor); if (!m) return null;
          const x = Math.round(m.w * (0.08 + rr() * 0.84)), d = Math.round((0.2 + rr() * 0.7) * 100) / 100;
          return { map: m.key, spot: { key: `wander:${who}:${k}`, name: 'nowhere in particular', x, d, act: 'stand', kind: 'gate' } };
        };
        const cand = job.spots.map((k) => spotIndex.get(k) ?? wander(k, 0)).filter((x): x is { map: string; spot: Spot } => !!x);
        const stops: Npc['stops'] = [];
        const n = 3 + Math.floor(rr() * 2);
        for (let k = 0; k < n; k++) {
          let c0 = spotIndex.get('fountain')!;
          if (cand.length) { const least = Math.min(...cand.map((c) => used.get(c.spot.key) ?? 0)); const pool = cand.filter((c) => (used.get(c.spot.key) ?? 0) === least); c0 = pool[Math.floor(rr() * pool.length)]; }
          if (c0.spot.key.startsWith('wander:')) c0 = wander(c0.map, k) ?? c0; // 산책은 매번 다른 곳
          used.set(c0.spot.key, (used.get(c0.spot.key) ?? 0) + 1);
          stops.push({ map: c0.map, spot: c0.spot, dur: 14 + rr() * 30 });
        }
        // 누구나 한 번은 그냥 서성인다 — 자리(분수·카페·벤치) 주변에만 몰리지 않고 광장의 빈 데도 사람이 있게. 자기 일터 지도 안에서
        { const w = wander(stops[0]?.map ?? 'square', 9); if (w) stops.splice(1 + Math.floor(rr() * stops.length), 0, { map: w.map, spot: w.spot, dur: 10 + rr() * 20 }); }
        if (home) { const hs = home.spots.filter((s) => s.kind !== 'door'); stops.splice(Math.floor(rr() * stops.length), 0, { map: home.key, spot: hs[Math.floor(rr() * hs.length)], dur: 30 + rr() * 60 }); }
        const angry = content.angry.includes(handle) || rr() < job.temper;
        return { who, tx: 0, td: 0.5, job, seed, stops, x: 0, d: 0.5, map: stops[0].map, face: 1 as const, item: job.item, mode: 'routine' as Mode, until: 0, tripUntil: 0, say: '', sayUntil: 0, moving: false, act: 'stand', angry, threw: 0, swing: 0, target: null, owner: null };
      });
      thrown.current = [];
    };
    /** 지도 a → b 로 가는 문: a 의 출구 중 b 로 가는 것, 없으면 광장으로 가는 것(집→공원처럼 두 번 건너는 경우) */
    const doorTo = (from: string, to: string) => { const m = mapOf(from); return m.exits.find((e) => e.to === to) ?? m.exits.find((e) => e.to === 'square') ?? m.exits[0]; };
    /** 자리에 설 곳 — 앉는 자리·운동기구는 정확히 그 위, 나머지는 ±110px·앞뒤 ±0.18 로 흩어진다(씨앗+정거장 번호로 결정적). 뭉치면 누가 누군지 안 보인다 */
    const EXACT: PropKind[] = [...SITTABLE, 'pullbar', 'benchpress', 'rack'];
    const standAt = (spot: Spot, seed: number, i: number): [number, number] => {
      if (EXACT.includes(spot.kind) || spot.act === 'sit') return [spot.x, spot.d];
      const r = rng(hash(`${seed}:${i}`)); return [spot.x + (r() - 0.5) * 300, Math.min(0.95, Math.max(0.05, spot.d + (r() - 0.5) * 0.36))];
    };
    const routine = (n: Npc, t: number) => {
      type Seg = { map: string; x0: number; d0: number; x1: number; d1: number; dur: number; act: string; away?: boolean };
      const segs: Seg[] = [];
      const sp = RESIDENT_SPEED * n.job.speed;
      for (let i = 0; i < n.stops.length; i++) {
        const a = n.stops[i], b = n.stops[(i + 1) % n.stops.length];
        const [ax, ad] = standAt(a.spot, n.seed, i), [bx, bd] = standAt(b.spot, n.seed, (i + 1) % n.stops.length);
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
    // 오리 — 연못마다 3~5마리, 씨앗으로 정해져 모두 같은 수를 본다. 자리(x,d)는 매 프레임 목표를 향해 스프링으로 따라간다
    const ducks: Duck[] = [];
    for (const m of maps.current) for (const sp of m.spots.filter((s) => s.kind === 'pond')) {
      const r = rng(hash(`duck:${sp.key}`)); const n = 3 + Math.floor(r() * 3);
      for (let i = 0; i < n; i++) ducks.push({ map: m.key, pond: sp.key, baseX: sp.x, baseD: sp.d, seed: Math.floor(r() * 1e6), x: sp.x, d: sp.d, scareUntil: 0 });
    }

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      const dt = Math.min(0.1, (now - last) / 1000); last = now; const t = wall() / 1000;
      if (hour() !== curHour) { curHour = hour(); spawn(); }
      const b = body.current, i = input.current, st = stats.current; const cur = mapOf(mapKey.current); const props = propsOf.get(cur.key)!;
      const here = (n: Npc) => n.map === cur.key;
      const myPose = (): FigPose => b.tripped > 0 ? 'trip' : b.swing > 0 ? b.swingKind : b.z > 0 ? 'jump' : b.exercise > 0 ? b.exerciseKind : b.watering > 0 ? 'water' : b.fishing > 0 ? 'fish' : b.feeding > 0 ? 'feed' : b.eating > 0 ? (b.sitting ? 'eat' : 'chew') : b.sitting ? seatPose(b.seat) : b.still ? (b.still === 'tv' ? 'watch' : 'read') : b.moving ? 'run' : 'stand';
      const knock = (byName: string, line: string, fine = 0) => {
        b.hurt = 1.2; b.vz = 0; b.z = 0; b.sitting = false; b.eating = 0; b.exercise = 0; b.still = null; b.watering = 0; b.tripped = 0; b.fishing = 0; b.feeding = 0;
        for (const it of b.stack) drop(it, b.x + (Math.random() - 0.5) * 80, Math.max(0, Math.min(1, b.d + (Math.random() - 0.5) * 0.2)), null);
        b.stack = []; b.wearing.clear(); say(`${byName}: ${line}${fine ? ` (fined ${fine})` : ''}`); st.chasedSince = 0;
      };
      if (st.pendingKnock && !spectator) { const k = st.pendingKnock; st.pendingKnock = null; knock(k.by, k.line); }
      /** 던지기 — 들고 있는 것 중 맨 위를 앞으로. 궤적은 모두에게(ev throw), 맞은 주민·사람·소품과 떨어진 물건은 내 화면이 판정해 낸다 */
      const throwTop = () => {
        const it = b.stack.pop()!; b.wearing.delete(it); b.swing = 0.3; b.swingKind = 'throw';
        const th = { item: it, map: cur.key, x: b.x + b.face * 14, d: b.d, z: 34 + b.z, vx: b.face * 430, vz: 170, from: -1, by: me!.id };
        thrown.current.push(th); emit({ k: 'throw', item: it, m: th.map, x: Math.round(th.x), d: th.d, z: th.z, vx: th.vx, vz: th.vz, from: -1 });
      };
      const hit = (kind: 'punch' | 'kick') => {
        if (kind === 'punch' && b.stack.length) { throwTop(); return; }
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
          emit({ k: 'break', key: pr.key, hp: st2.hp, brokeAt: st2.brokeAt ? wall() : 0 });
        }
      };
      // ── 나 ──
      let exitNear = '';
      if (!spectator && b.hurt > 0) { b.hurt = Math.max(0, b.hurt - dt); b.moving = false; }
      if (!spectator && b.eating > 0) { b.eating = Math.max(0, b.eating - dt); b.moving = false; } // 먹는 동안 잠깐 멈춘다
      if (!spectator && b.exercise > 0) { b.exercise = Math.max(0, b.exercise - dt); b.moving = false; } // 운동하는 동안 잠깐 멈춘다
      if (!spectator && b.watering > 0) { b.watering = Math.max(0, b.watering - dt); b.moving = false; } // 물 주는 동안 잠깐 멈춘다
      if (!spectator && b.tripped > 0) { b.tripped = Math.max(0, b.tripped - dt); b.moving = false; } // 헛디뎌 넘어진 동안 잠깐 멈춘다
      if (!spectator && b.feeding > 0) { b.feeding = Math.max(0, b.feeding - dt); b.moving = false; } // 오리에게 모이를 주는 동안 잠깐 멈춘다
      if (!spectator && b.fishing > 0) { // 입질 기다리는 동안 낚싯대를 드리우고 앉아 있는다 — 다 되면 잡는다
        b.fishing = Math.max(0, b.fishing - dt); b.moving = false;
        if (b.fishing === 0) {
          const caught = pick(POND_ITEMS).name;
          b.stack.push('fish'); say(`Caught ${caught}.`, 2500);
          said.current.set(me!.id, { body: `caught ${caught}`, until: now + 3000 });
          void complete('fish1');
        }
      }
      if (b.swing > 0) b.swing = Math.max(0, b.swing - dt);
      if (!spectator && ready.current && b.hurt <= 0 && b.eating <= 0 && b.exercise <= 0 && b.watering <= 0 && b.tripped <= 0 && b.fishing <= 0 && b.feeding <= 0) {
        const dx = (i.right ? 1 : 0) - (i.left ? 1 : 0), dd = (i.down ? 1 : 0) - (i.up ? 1 : 0);
        const slow = 1 - Math.min(0.5, b.stack.length * 0.12);
        if (b.sitting) { b.moving = false; if (dx || dd || i.jump) b.sitting = false; } // 앉아 있으면 움직이려는 순간 일어난다(이번 프레임엔 아직 안 움직임)
        else if (b.still) { b.moving = false; if (dx || dd || i.jump) b.still = null; } // TV·책장 앞에 서 있으면 움직이려는 순간 멈춘다(계속 봄)
        else {
          if (dx || dd) { b.x = Math.max(20, Math.min(cur.w - 20, b.x + dx * PLAYER_SPEED * slow * dt)); b.d = Math.max(0, Math.min(1, b.d + dd * 1.5 * dt)); if (dx) b.face = dx as 1 | -1; }
          // 빈손으로 전속력일 때 바닥의 물건을 밟으면 헛디딘다 — 주민이 쫓다 넘어지는 것과 같은 자세
          if ((dx || dd) && b.stack.length === 0) {
            const li = [...loose.current.values()].find((x) => x.map === cur.key && !x.dunked && dist(b.x, b.d, x.x, x.d) < 20);
            if (li && Math.random() < 0.5) { b.tripped = 1.2; say(`Tripped over the ${ITEMS[li.item]}.`, 1400); }
          }
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
            else if (q.kind === 'fetch' && b.stack.includes(q.item!)) { b.stack.splice(b.stack.indexOf(q.item!), 1); b.wearing.delete(q.item!); n.item = q.item!; finishQuest(q, n); }
            else if (q.kind === 'pond' && b.stack.includes('fish')) { b.stack.splice(b.stack.indexOf('fish'), 1); n.item = 'fish'; finishQuest(q, n); }
            else if (q.kind === 'wear' && b.wearing.has(q.item!)) finishQuest(q, n);
            else if (q.kind === 'revenge' && st.shoves.some((x) => x.who === q.target && now - x.at < 120000)) finishQuest(q, n);
            else { quests.current.set(n.who, q); setQuestList([...quests.current.values()]); n.say = q.ask; n.sayUntil = now + 3500; n.face = (b.x >= n.x ? 1 : -1) as 1 | -1; }
          }
        }
        if (i.shove && !shoveWas && b.z === 0 && b.swing <= 0) hit('punch');
        if (i.kick && !kickWas && b.swing <= 0) hit('kick');
        if (i.grab && !grabWas && b.z === 0) {
          const water1 = cur.spots.find((s) => WATER_SPOTS.includes(s.key) && dist(b.x, b.d, s.x, s.d) < 90);
          const pondSpot = cur.spots.find((s) => s.kind === 'pond' && dist(b.x, b.d, s.x, s.d) < 110);
          if (b.stack.length && b.stack.includes('rod') && water1) { // 대를 든 채 물가에서 — 던지고 기다린다(4~12초)
            b.fishing = 4 + Math.random() * 8; b.x = water1.x; b.d = Math.min(1, water1.d + 0.04); say('Cast the line.', 1200);
          } else if (b.stack.length && pondSpot && FOOD.includes(b.stack[b.stack.length - 1])) { // 연못가에서 먹을 것을 들고 — 오리에게 준다
            b.stack.pop(); b.feeding = 1.4; b.x = pondSpot.x; b.d = Math.min(0.97, pondSpot.d + 0.04);
            say('Fed the ducks.', 1500); void complete('feed1');
          } else if (b.stack.length) {
            const it = b.stack.pop()!;
            const bin = cur.spots.find((s) => s.kind === 'bin' && dist(b.x, b.d, s.x, s.d) < 90);
            const water = cur.spots.find((s) => WATER_SPOTS.includes(s.key) && dist(b.x, b.d, s.x, s.d) < 90);
            const spotNear = cur.spots.find((s) => (s.kind === 'bench' || s.kind === 'cafe' || s.kind === 'table' || s.kind === 'bed') && dist(b.x, b.d, s.x, s.d) < 90);
            const pondSpot = cur.spots.find((s) => s.kind === 'pond' && dist(b.x, b.d, s.x, s.d) < 140);
            if (bin) { // 통에 들어가면 그걸로 끝 — 줍기 목록에도, 바닥에도 다시 나타나지 않는다(먹기와 같은 규칙: 새 ev 없이 다음 pos.s 로 남에게도 보인다)
              say(`Binned the ${ITEMS[it]}.`, 1500); void complete(`bin:${it}:${bin.key}`);
              for (const q of quests.current.values()) if (q.kind === 'bin' && q.item === it) { const n = npcs.current.find((p) => p.who === q.who); if (n) finishQuest(q, n); }
            }
            else if (pondSpot && FOOD.includes(it)) { feedRef.current = { map: cur.key, x: b.x, d: b.d, until: now + 3000 }; say('The ducks converge.', 1500); void complete(`feed:${pondSpot.key}`); }
            else if (FOOD.includes(it) && spotNear && spotNear.kind !== 'bed') { b.eating = 1; say(`Ate the ${ITEMS[it]}.`, 1500); } // 카페·식탁·벤치 — 침대에서는 안 먹는다
            else if (WEARABLE.includes(it) && !water && !spotNear) { // 몸에 걸치기 — 근처에 물·벤치·카페 등 아무것도 없을 때만(있으면 원래대로 놓기/적시기)
              b.stack.push(it);
              if (b.wearing.has(it)) { b.wearing.delete(it); say(`Took off the ${ITEMS[it]}.`, 1200); }
              else { b.wearing.add(it); say(`Put on the ${ITEMS[it]}.`, 1200); void complete(`wear:${it}`); for (const q of quests.current.values()) if (q.kind === 'wear' && q.item === it) { const n = npcs.current.find((p) => p.who === q.who); if (n) finishQuest(q, n); } }
            }
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
              else {
                const seat = cur.spots.find((s) => SITTABLE.includes(s.kind) && dist(b.x, b.d, s.x, s.d) < 90);
                const gym = cur.spots.find((s) => (s.kind === 'pullbar' || s.kind === 'benchpress') && dist(b.x, b.d, s.x, s.d) < 90);
                const screen = cur.spots.find((s) => (s.kind === 'tv' || s.kind === 'shelf') && dist(b.x, b.d, s.x, s.d) < 90);
                const garden = cur.spots.find((s) => s.kind === 'garden' && dist(b.x, b.d, s.x, s.d) < 90);
                const rack = cur.spots.find((s) => s.kind === 'rack' && dist(b.x, b.d, s.x, s.d) < 90);
                if (seat) { b.sitting = !b.sitting; if (b.sitting) { b.x = seat.x; b.d = seat.d; b.seat = seat.kind; } }
                else if (gym) { b.exercise = 2.4; b.exerciseKind = gym.kind === 'pullbar' ? 'pullup' : 'press'; b.x = gym.x; b.d = gym.d; say(gym.kind === 'pullbar' ? 'Pull-ups.' : 'Bench press.', 1200); }
                else if (screen) { b.still = b.still ? null : (screen.kind as 'tv' | 'shelf'); if (b.still) { b.x = screen.x; b.d = screen.d; } }
                else if (garden) {
                  b.watering = 1.4; b.x = garden.x; b.d = garden.d; say(`Watered ${garden.name}.`, 1500); void complete(`water:${garden.key}`);
                  for (const q of quests.current.values()) if (q.kind === 'water' && q.spot === garden.key) { const n = npcs.current.find((p) => p.who === q.who); if (n) finishQuest(q, n); }
                }
                else if (rack) { b.stack.push('rod'); say('Took a rod from the rack.', 1500); }
              }
            }
            if (b.stack.length >= 3) void complete('collect3');
          }
        }
        jumpWas = i.jump; grabWas = i.grab; shoveWas = i.shove; kickWas = i.kick; talkWas = i.talk;
      }
      if (!spectator && ready.current && ws.current?.readyState === 1 && now - sent > 66) { sent = now; ws.current.send(JSON.stringify({ t: 'pos', x: Math.round(b.x), y: Math.round(b.d * 1000), z: Math.round(b.z), s: b.stack.map((it) => b.wearing.has(it) ? `${it}!` : it).join(','), pose: b.hurt > 0 ? 'hurt' : myPose(), face: b.face, m: cur.key })); }
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
        if (n.mode === 'trip') { // 헛디뎌 잠깐 멈춤 — 회복하면 시계가 남아 있으면 계속 쫓고, 다 됐으면 포기
          mineOff.push(n); n.moving = false;
          if (now > n.tripUntil) { if (now > n.until) { n.mode = 'return'; n.say = pick(content.giveup); n.sayUntil = now + 2500; npcEv(n, { say: n.say }); void complete(`sit:${n.who}`); } else { n.mode = 'chase'; npcEv(n); } }
          continue;
        }
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
          // 헛디딤 — 초당 확률(은퇴자·물건 든 채면 더 높다), 잡기 직전이라도 넘어지면 그대로 놓친다
          const tripP = (0.045 + (n.job.key === 'retired' ? 0.11 : 0) + (n.item ? 0.05 : 0)) * dt;
          if (Math.random() < tripP) {
            if (n.item) { drop(n.item, n.x + (Math.random() - 0.5) * 24, n.d, n.who); n.item = null; }
            n.mode = 'trip'; n.tripUntil = now + 1200; n.until -= 2000; n.moving = false; n.swing = 0;
            n.say = pick(['ow.', 'i am fine.', 'that never happened.', 'nothing to see here.', 'my ankle.']); n.sayUntil = now + 2000;
            npcEv(n, { say: n.say });
            continue;
          }
          if (n.item && far > 70 && far < 170 && now - n.threw > 4000 && b.hurt <= 0) { n.threw = now; n.swing = 0.3; n.swingKind = 'throw'; const th = { item: n.item, map: cur.key, x: n.x, d: n.d, z: 30, vx: Math.sign(b.x - n.x) * 380, vz: 120, from: n.who }; thrown.current.push(th); emit({ k: 'throw', ...th, m: th.map }); n.item = null; n.say = pick(content.thrown); n.sayUntil = now + 1500; }
          const ddx = b.x - n.x, ddd = b.d - n.d; const len = Math.hypot(ddx, ddd * 400) || 1;
          n.x += (ddx / len) * speed * dt; n.d = Math.max(0, Math.min(1, n.d + (ddd * 400 / len) * speed * dt / 400)); n.face = ddx >= 0 ? 1 : -1; n.moving = true;
          if (far < 26 && b.z === 0 && b.hurt <= 0) {
            n.swing = 0.28; n.swingKind = 'punch'; const mine = b.stack.find((it) => it === n.job.item);
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
        if (!n.moving && n.act !== 'away' && n.item && FOOD.includes(n.item)) { // 먹을 것을 든 채 멈춰 서면 어디서든 먹는다 — 연못이면 오리에게 준다(사람과 같은 규칙)
          const pondHere = here(n) ? cur.spots.find((s) => s.kind === 'pond' && dist(n.x, n.d, s.x, s.d) < 90) : undefined;
          n.act = pondHere ? 'feed' : 'eat';
          if (pondHere) feedRef.current = { map: n.map, x: n.x, d: n.d, until: now + 400 };
        }
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
      if (!spectator && now - npcSent > 200 && ws.current?.readyState === 1) { npcSent = now; for (const n of mineOff) ws.current.send(JSON.stringify({ t: 'ev', ev: { k: 'npcpos', who: n.who, x: Math.round(n.x), d: Math.round(n.d * 100) / 100, face: n.face, moving: n.moving, m: n.map, swing: n.swing > 0.15 ? 1 : 0, sk: n.swingKind ?? 'punch' } })); }
      for (const th of [...thrown.current]) {
        th.x += th.vx * dt; th.vz -= 700 * dt; th.z += th.vz * dt;
        const gone = () => { thrown.current = thrown.current.filter((x) => x !== th); };
        if (th.remote) { if (th.z <= 0) gone(); continue; } // 남의 것 — 궤적만
        // 주민이 던진 것이 나를 맞힌다
        if (th.from >= 0 && !spectator && b.hurt <= 0 && th.map === cur.key && Math.abs(th.x - b.x) < 22 && Math.abs(th.d - b.d) < 0.12 && th.z < 50 + b.z && th.z > b.z - 10) { knock(residents[th.from].handle, pick(content.thrown)); gone(); drop(th.item, th.x, th.d, th.from); continue; }
        if (th.from < 0 && th.z < 60) {
          // 내가 던진 것 — 주민을 맞히면 넘어지고, 사람을 맞히면 그 사람 화면이 넘어짐을 처리한다
          const n = npcs.current.find((p) => here(p) && p.mode !== 'down' && p.act !== 'away' && Math.abs(th.x - p.x) < 20 && Math.abs(th.d - p.d) < 0.1);
          if (n) { n.mode = 'down'; n.owner = me!.id; n.until = now + 1600; n.face = (th.vx > 0 ? -1 : 1) as 1 | -1; n.x += Math.sign(th.vx) * 20; n.say = pick(content.shoved); n.sayUntil = now + 2000; if (n.item) { drop(n.item, n.x + Math.sign(th.vx) * 26, n.d, n.who); n.item = null; } npcEv(n, { say: n.say }); st.shoves = [...st.shoves.filter((x) => now - x.at < 10000), { who: n.who, at: now }]; say(`Hit ${residents[n.who].handle} with the ${ITEMS[th.item]}.`, 1500); gone(); drop(th.item, th.x, th.d, null); continue; }
          const o = [...others.current.values()].find((p) => p.map === cur.key && p.status === 'active' && Math.abs(th.x - p.x) < 22 && Math.abs(th.d - p.d) < 0.12 && th.z < 50 + p.z);
          if (o) { emit({ k: 'hitp', uid: o.uid, byName: me!.handle, kind: 'throw', item: th.item }); say(`Hit ${o.handle} with the ${ITEMS[th.item]}.`, 1500); gone(); drop(th.item, th.x, th.d, null); continue; }
        }
        if (th.z <= 0) {
          gone(); drop(th.item, th.x, th.d, th.from >= 0 ? th.from : null);
          // 내가 던진 것이 소품에 떨어지면 발차기 한 번만큼 상한다
          if (th.from < 0) { const pr = props.find((p) => BREAKABLE.includes(p.kind) && dist(th.x, th.d, p.x, p.d) < 34); if (pr) { const st2 = broken.current.get(pr.key) ?? { hp: 3, brokeAt: 0 }; if (!st2.brokeAt) { st2.hp -= 1; if (st2.hp <= 0) { st2.brokeAt = now; say(`The ${ITEMS[th.item]} broke ${pr.name}.`); void complete(`break:${pr.key}`); } emit({ k: 'break', key: pr.key, hp: st2.hp, brokeAt: st2.brokeAt ? wall() : 0 }); } } }
        }
      }
      for (const [k, v] of broken.current) if (v.brokeAt && now - v.brokeAt > 300000) broken.current.delete(k); // 아무도 안 고치면 5분 뒤 저절로
      // ── 오리 — 느린 원을 그리며 헤엄치다, 뛰어드는 사람이나 던진 것이 가까이 오면(각자 화면이 판단) 파닥이며 흩어진다 ──
      for (const dck of ducks) {
        if (dck.map !== cur.key) continue;
        const amp = 30 + (dck.seed % 50), ampD = 0.04 + (dck.seed % 8) / 160, sp2 = 0.12 + (dck.seed % 11) / 70, ph = (dck.seed % 628) / 100;
        const bx = dck.baseX + Math.cos(t * sp2 + ph) * amp, bdd = Math.min(0.98, Math.max(0.5, dck.baseD + Math.sin(t * sp2 * 1.6 + ph) * ampD));
        let threat: { x: number; d: number } | null = null;
        if (!spectator && b.moving && dist(b.x, b.d, bx, bdd) < 90) threat = { x: b.x, d: b.d };
        if (!threat) for (const o of others.current.values()) { if (o.map === cur.key && o.status === 'active' && dist(o.x, o.d, bx, bdd) < 90) { threat = { x: o.x, d: o.d }; break; } }
        if (!threat) for (const th of thrown.current) { if (th.map === cur.key && th.z > 0 && dist(th.x, th.d, bx, bdd) < 70) { threat = { x: th.x, d: th.d }; break; } }
        if (threat) dck.scareUntil = now + 1600;
        if (now < dck.scareUntil) {
          const away = threat ?? { x: bx - 40, d: bdd };
          const fx = bx + Math.sign(bx - away.x || (dck.seed % 2 ? 1 : -1)) * 50;
          dck.x += (fx - dck.x) * Math.min(1, dt * 7); dck.d += (bdd - dck.d) * Math.min(1, dt * 7);
        } else if (feedRef.current.map === cur.key && now < feedRef.current.until && dist(feedRef.current.x, feedRef.current.d, bx, bdd) < 220) {
          dck.x += (feedRef.current.x - dck.x) * Math.min(1, dt * 2.2); dck.d += (feedRef.current.d - dck.d) * Math.min(1, dt * 2.2);
        } else { dck.x += (bx - dck.x) * Math.min(1, dt * 2); dck.d += (bdd - dck.d) * Math.min(1, dt * 2); }
      }
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
      for (const dck of ducks) {
        if (dck.map !== cur.key) continue; const fx = sx(dck.x); if (fx < -40 || fx > W + 40) continue;
        const pose: CritterPose = now < dck.scareUntil ? 'flap' : (feedRef.current.map === cur.key && now < feedRef.current.until && dist(feedRef.current.x, feedRef.current.d, dck.x, dck.d) < 80 ? 'feed' : 'paddle');
        layer.push({ d: dck.d - 0.002, f: () => critter(ctx, 'duck', fx, dy(dck.d) * s, ds(dck.d) * s, pose, t) });
      }
      for (const th of thrown.current) { if (th.map !== cur.key) continue; const fx = sx(th.x); layer.push({ d: th.d, f: () => item(ctx, th.item, fx, (dy(th.d) - th.z) * s - 6 * s, ds(th.d) * s) }); }
      for (const n of npcs.current) {
        if (!here(n) || n.act === 'away') continue;
        const fx = sx(n.x); if (fx < -100 || fx > W + 100) continue;
        layer.push({ d: n.d, f: () => {
          const fy = dy(n.d) * s, fs = ds(n.d) * s;
          const seat = seatAt(cur, n.x, n.d);
          const pose: FigPose = n.mode === 'down' ? 'hurt' : n.mode === 'trip' ? 'trip' : n.swing > 0 ? (n.swingKind ?? 'punch') : n.moving ? 'run' : n.mode === 'repair' ? 'fix' : actPose(n.act, seat?.kind);
          const lift = SEATED.includes(pose) && seat ? (SEAT_LIFT[seat.kind] ?? 0) * fs : 0;
          if (n.mode === 'down') { ctx.save(); ctx.translate(fx, fy); ctx.rotate(n.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, '#3a2f36', t, false); ctx.restore(); }
          else figure(ctx, fx, fy - lift, fs, pose, n.face, n.job.key === 'cop' ? '#1f3a5a' : '#3a2f36', pose === 'swing' ? t : t + n.seed % 5, false); // 그네는 소품의 줄과 같은 위상이어야 하니 t 그대로
          if (n.item && n.mode !== 'down') { const wy = WORN_Y[n.item]; item(ctx, n.item, wy ? fx : fx + n.face * 14 * fs, fy - (wy ?? 26) * fs, fs * 0.8); } // 모자·안경은 직업 물건이라도 몸에 걸친 것처럼 그린다(사람이 입는 것과 같은 위치)
          if (n.act !== 'stand' && (n.mode === 'routine' || n.mode === 'repair') && !n.moving) actIcon(ctx, n.mode === 'repair' ? 'repair' : n.act, fx + 18 * fs, fy - 46 * fs, fs);
          name(ctx, fx, fy - 58 * fs, s, `${residents[n.who].handle} · ${n.job.name}`);
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
          else { const pose = (KNOWN_POSES.includes(o.pose) ? o.pose : 'stand') as FigPose; const lift = SEATED.includes(pose) ? (SEAT_LIFT[seatAt(cur, o.x, o.d)?.kind ?? 'bench'] ?? 0) * fs : 0; figure(ctx, fx, fy - lift, fs, pose, o.face, col, t, false); }
          const carried = o.stack.filter((it) => !o.worn.has(it));
          carried.forEach((it, k) => item(ctx, it, fx, fy - (48 + k * 12) * fs, fs * 0.8));
          for (const it of o.worn) if (o.stack.includes(it)) item(ctx, it, fx, fy - (WORN_Y[it] ?? 44) * fs, fs * 0.8);
          name(ctx, fx, fy - (58 + carried.length * 12) * fs, s, o.handle);
          const sd = said.current.get(o.uid); if (sd && now < sd.until) bubble(ctx, fx, fy - (70 + carried.length * 12) * fs, s, sd.body);
        } });
      }
      if (!spectator && ready.current) layer.push({ d: b.d, f: () => {
        const fx = sx(b.x), fy = (dy(b.d) - b.z) * s, fs = ds(b.d) * s;
        if (b.z > 0) { ctx.fillStyle = 'rgba(0,0,0,0.15)'; ctx.beginPath(); ctx.ellipse(fx, dy(b.d) * s, 12 * fs, 4 * fs, 0, 0, 6.29); ctx.fill(); }
        if (b.hurt > 0) { ctx.save(); ctx.translate(fx, fy); ctx.rotate(-b.face * 1.4); figure(ctx, 0, 0, fs, 'hurt', 1, figureColor(me!.id), t, false); ctx.restore(); }
        else figure(ctx, fx, fy - (b.sitting ? (SEAT_LIFT[b.seat] ?? 0) * fs : 0), fs, myPose(), b.face, figureColor(me!.id), t, false);
        if (b.still) actIcon(ctx, b.still === 'tv' ? 'watch' : 'read', fx + 18 * fs, fy - 46 * fs, fs);
        const carried = b.stack.filter((it) => !b.wearing.has(it));
        carried.forEach((it, k) => item(ctx, it, fx, fy - (48 + k * 12) * fs, fs * 0.8));
        for (const it of b.wearing) if (b.stack.includes(it)) item(ctx, it, fx, fy - (WORN_Y[it] ?? 44) * fs, fs * 0.8);
        name(ctx, fx, fy - (58 + carried.length * 12) * fs, s, me!.handle);
        const sd = said.current.get(me!.id); if (sd && now < sd.until) bubble(ctx, fx, fy - (70 + carried.length * 12) * fs, s, sd.body);
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

  const send = () => { const b = line.trim(); if (!b || ws.current?.readyState !== 1) return; ws.current.send(JSON.stringify({ t: 'chat', body: b })); if (me) said.current.set(me.id, { body: b, until: performance.now() + 4000 }); setLine(''); }; // 내 말은 바로 내 머리 위에(방은 나에겐 되돌려 주지 않는다)
  const hold = (k: keyof typeof input.current) => ({ onPointerDown: () => { input.current[k] = true; }, onPointerUp: () => { input.current[k] = false; }, onPointerLeave: () => { input.current[k] = false; } });

  return (
    <div ref={wrap} className="mx-auto w-full max-w-[960px]">
      <div className="flex flex-wrap items-center justify-between gap-2 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink-soft">
        <span>{hud.map}{hud.carry ? <span className="font-normal normal-case tracking-normal"> — carrying {hud.carry}</span> : ''}{hud.exit ? <span className="font-normal normal-case tracking-normal"> — ↑ {hud.exit}</span> : ''}</span>
        <span>{hud.online} here · {doneList.length}/{tasks.length} done today</span>
      </div>
      <div className="relative mt-2 overflow-hidden rounded-xl border border-hairline bg-[#eef0f2]">
        <canvas ref={canvas} className="block w-full touch-none" />
        {loading && <div className="absolute inset-0 grid place-items-center bg-[#eef0f2]"><p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">{spectator ? 'Finding someone to watch…' : 'Finding your spot…'}</p></div>}
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
      {!spectator && !TOUCH && <p className="mt-1.5 font-mono text-[10.5px] text-ink-soft">← → ↑ ↓ move · SPACE jump · X punch / throw · Z kick · C use · E talk</p>}
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
    case 'pullbar': { ctx.strokeStyle = '#5b4f56'; ctx.lineWidth = 4 * s; ctx.beginPath(); ctx.moveTo(-28 * s, 0); ctx.lineTo(-28 * s, -60 * s); ctx.lineTo(28 * s, -60 * s); ctx.lineTo(28 * s, 0); ctx.stroke(); break; }
    case 'benchpress': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-22 * s, -14 * s, 44 * s, 6 * s); ctx.fillRect(-19 * s, -9 * s, 4 * s, 9 * s); ctx.fillRect(15 * s, -9 * s, 4 * s, 9 * s); ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 3 * s; ctx.beginPath(); ctx.moveTo(-30 * s, -34 * s); ctx.lineTo(30 * s, -34 * s); ctx.stroke(); ctx.fillStyle = '#5b4f56'; ctx.beginPath(); ctx.arc(-30 * s, -34 * s, 6 * s, 0, 6.29); F('#5b4f56'); ctx.beginPath(); ctx.arc(30 * s, -34 * s, 6 * s, 0, 6.29); F('#5b4f56'); break; }
    case 'rack': { ctx.fillStyle = '#8b6b4a'; ctx.fillRect(-3 * s, -40 * s, 6 * s, 40 * s); ctx.fillRect(-16 * s, -40 * s, 32 * s, 4 * s); ctx.strokeStyle = '#5b4f56'; ctx.lineWidth = 1.6 * s; for (const rx of [-9, 3]) { ctx.beginPath(); ctx.moveTo(rx * s, -38 * s); ctx.lineTo((rx + 26) * s, -68 * s); ctx.stroke(); } break; }
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
    case 'rod': ctx.beginPath(); ctx.moveTo(-8 * s, 6 * s); ctx.lineTo(10 * s, -10 * s); ctx.stroke(); break;
    case 'fish': ctx.beginPath(); ctx.ellipse(0, 0, 9 * s, 4.5 * s, 0.3, 0, 6.29); F('#8fb8cc'); ctx.beginPath(); ctx.moveTo(-8 * s, 0); ctx.lineTo(-13 * s, -4 * s); ctx.lineTo(-13 * s, 4 * s); ctx.closePath(); F('#8fb8cc'); break;
  }
  ctx.restore();
}
function actIcon(ctx: CanvasRenderingContext2D, act: string, x: number, y: number, s: number) {
  ctx.fillStyle = '#5b4f56'; ctx.font = `${10 * s}px ui-monospace, monospace`; ctx.textAlign = 'left';
  ctx.fillText(({ read: 'reading', phone: 'on the phone', sit: 'sitting', water: 'watering', sweep: 'sweeping', shop: 'shopping', eat: 'eating', repair: 'fixing it', pushup: 'push-ups', pullup: 'pull-ups', press: 'bench press', watch: 'watching', fish: 'fishing', feed: 'feeding the ducks' } as Record<string, string>)[act] ?? '', x, y);
}
function name(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) { ctx.fillStyle = '#5b4f56'; ctx.font = `bold ${10.5 * s}px ui-monospace, monospace`; ctx.textAlign = 'center'; ctx.fillText(text, x, y); }
function bubble(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, text: string) {
  ctx.font = `bold ${11 * s}px system-ui, sans-serif`; ctx.textAlign = 'left';
  const w = ctx.measureText(text).width + 14 * s, h = 20 * s; const bx = Math.min(ctx.canvas.width - w - 4, Math.max(4, x - w / 2)), by = y - 22 * s;
  ctx.fillStyle = '#ffffff'; ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1; ctx.beginPath(); ctx.roundRect(bx, by, w, h, 6 * s); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#1b0c15'; ctx.fillText(text, bx + 7 * s, by + 14 * s);
}
