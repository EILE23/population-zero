/**
 * Climb — 다 같이 오르는 끝없는 탑의 순수 규칙. DOM 도 React 도 없다(앱과 웹이 같은 걸 돌린다).
 *
 * 세계: 폭 960px, 위로 무한, 영구(리셋 없음). 600px 마다 한 '층(band)'. 층마다 정석 발판 6개가 지그재그로, 가끔 지름길(작고 먼 발판),
 * 다섯 층마다 쉼터(넓은 발판). 발판엔 성질이 붙는다 — 스프링(높이 튐)·얼음(미끄러짐)·움직임·부서짐. 지형은 (씨앗, 층 번호) 의
 * 결정적 함수라 서버 없이 모두가 같은 탑을 본다. 움직이는 발판은 벽시계(Date.now) 의 함수라 모두에게 같은 자리에 있다.
 *
 * 주민은 오르지 않는다 — 층마다 배치된 NPC 다: 밀어 떨어뜨리는 놈, 길을 막고 선 놈, 왔다갔다 하는 놈, 앉아서 한마디 하는 놈.
 * 어느 층에 누가 있는지, 지금 어디서 뭘 하는지도 (씨앗, 층, 시각) 의 함수다. 사람은 서버(DO)가 위치를 들고 있어 서로 보인다.
 */
export const WORLD_W = 960;
export const BAND_H = 600;
export const G = 2400;          // px/s²
export const WALK = 170;        // px/s — 걷기는 느리다
export const RUN = 300;         // px/s — 점프 중 수평 속도(고정 — 공중 조작 없음, 점프킹 식)
export const JUMP_V = 860;      // px/s → 최고 154px, 체공 0.72s → 수평 215px (완충)
export const JUMP_MIN = 430;    // 살짝 눌렀을 때
export const CHARGE = 0.7;      // 초 — 이만큼 누르면 완충
export const SPLAT = 330;       // px — 이보다 높이서 떨어지면 찌부(잠깐 못 움직임)
export const REST_EVERY = 5;
export const HOPS = 6;
export const SEED = 0x505a; // 영구 탑 — 바꾸면 모두의 탑이 바뀐다. 바꾸지 않는다

export type Kind = 'std' | 'short' | 'rest' | 'spring' | 'ice' | 'move' | 'crumble';
export interface Platform { id: string; x: number; y: number; w: number; kind: Kind; amp?: number; freq?: number; phase?: number }

export function rng(seed: number) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
export const hash = (s: string) => { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; };

const cache = new Map<number, Platform[]>();
/** 한 층의 발판들 */
export function band(n: number): Platform[] {
  const hit = cache.get(n); if (hit) return hit;
  const r = rng(SEED ^ Math.imul(n + 1, 2654435761));
  const out: Platform[] = [];
  const base = n * BAND_H;
  if (n === 0) out.push({ id: 'ground', x: 0, y: 0, w: WORLD_W, kind: 'rest' });
  else if (n % REST_EVERY === 0) out.push({ id: `${n}r`, x: 180 + r() * 200, y: base, w: 400, kind: 'rest' });
  // 발판은 '이전 발판에서 닿는 거리 안'에만 놓는다 — 점프 사거리는 수평 ~215px(같은 높이)·수직 154px.
  // 층이 높을수록 간격이 벌어져 어려워지되 언제나 닿는다. 층 사이 연결도 같은 규칙(이전 층 마지막 발판에서 이어짐).
  const prevLast = n > 0 ? band(n - 1).filter((p) => p.kind !== 'rest' && p.kind !== 'short').at(-1) : null;
  let cx = prevLast ? prevLast.x + prevLast.w / 2 : WORLD_W / 2;   // 이전 발판 중심
  let side: 1 | -1 = cx > WORLD_W / 2 ? -1 : 1;
  let y = (prevLast ? prevLast.y : base) + 96 + r() * 28;
  if (n % REST_EVERY === 0 && n > 0) y = base + 96 + r() * 28;
  const stretch = Math.min(1, n / 60); // 0 → 1: 간격이 점점 벌어진다
  const spice = n < 2 ? 0 : Math.min(0.45, 0.12 + n * 0.006);
  for (let i = 0; i < HOPS; i++) {
    const w = 200 - stretch * 70 - r() * 40;                       // 200~90px
    const dy = 92 + stretch * 20 + r() * 26;                        // 수직 92~138px (최고점 154px)
    // 이 높이차에서 수평으로 닿는 거리(내려오며 착지) 에서 40px 여유 — 위로 갈수록 그 한계에 가깝게
    const reach = RUN * ((JUMP_V + Math.sqrt(JUMP_V * JUMP_V - 2 * G * dy)) / G) - 40;
    const gap = Math.min(reach, 60 + stretch * 70 + r() * (reach - 60 - stretch * 70)); // 가장자리 간 수평 거리
    // cx 는 이전 발판의 '가까운 가장자리'가 아니라 중심이라, 가장자리 간 거리 = gap 이 되도록 이전 반폭을 더한다
    const prevHalf = i === 0 ? (prevLast ? prevLast.w / 2 : 0) : out[out.length - 1].w / 2;
    let nx = cx + side * (prevHalf + gap + w / 2);
    if (nx - w / 2 < 0 || nx + w / 2 > WORLD_W) { side = -side as 1 | -1; nx = cx + side * (prevHalf + gap + w / 2); }
    nx = Math.max(w / 2, Math.min(WORLD_W - w / 2, nx));
    const x = nx - w / 2;
    cx = nx; side = r() < 0.7 ? -side as 1 | -1 : side; // 대개 지그재그, 가끔 같은 쪽으로 한 번 더
    let kind: Kind = 'std';
    const v = r();
    if (v < spice) {
      const k = r();
      kind = k < 0.3 ? 'spring' : k < 0.55 ? 'ice' : k < 0.8 ? 'move' : 'crumble';
    }
    const p: Platform = { id: `${n}.${i}`, x, y, w, kind };
    if (kind === 'move') { p.amp = 60 + r() * 80; p.freq = 0.25 + r() * 0.3; p.phase = r() * 6.28; }
    out.push(p);
    y += dy;
  }
  if (r() < 0.6) {
    // 지름길: 3번째 발판에서 한 번에 5번째 높이로 — 작고 높고 멀다(수직 148px, 완벽한 점프)
    const p3 = out[out.length - 4], p5 = out[out.length - 2];
    const sx = p3.x + p3.w / 2 + (p5.x + p5.w / 2 > p3.x + p3.w / 2 ? 150 : -150);
    out.push({ id: `${n}s`, x: Math.max(0, Math.min(WORLD_W - 60, sx - 30)), y: p3.y + 148, w: 60, kind: 'short' });
  }
  cache.set(n, out);
  return out;
}
export function around(y: number): Platform[] {
  const n = Math.max(0, Math.floor(y / BAND_H));
  return [...(n > 0 ? band(n - 1) : []), ...band(n), ...band(n + 1), ...band(n + 2)];
}
/** 바람 — 40층 위부터 층마다 방향·세기가 정해진다(공중에서 밀린다). 0 이면 없음 */
export function windOf(n: number): number {
  if (n < 40) return 0;
  const r = rng(SEED ^ Math.imul(n + 555, 1597334677));
  const v = r();
  return v < 0.45 ? 0 : (r() < 0.5 ? -1 : 1) * (60 + Math.min(120, (n - 40) * 1.5) * r());
}
/** 움직이는 발판의 지금 x — 벽시계 초 */
export const platX = (p: Platform, t: number) => (p.kind === 'move' ? p.x + (p.amp ?? 0) * Math.sin((p.freq ?? 0.3) * t * 6.2832 + (p.phase ?? 0)) : p.x);

// ── 사람 물리 ──
export type Pose = 'stand' | 'run' | 'jump' | 'sit' | 'fall' | 'hurt' | 'charge';
export interface Body { x: number; y: number; vx: number; vy: number; on: Platform | null; face: 1 | -1; idle: number; hurt: number; charge: number; apex: number }
/** jump 는 '누르고 있는 중' — 놓는 순간 뛴다 */
export interface Input { left: boolean; right: boolean; jump: boolean }
const HW = 10;

/**
 * 한 틱 — 점프킹 규칙. 발판 위에서 점프를 누르면 그 자리에서 힘을 모으고(걷지 못함), 놓으면 모은 만큼 뛴다.
 * 공중에선 조작이 없다 — 수평 속도는 뛸 때 정해지고(누른 방향으로 RUN, 방향 없으면 제자리 위로) 벽에 닿으면 튕긴다.
 * 높은 데서 떨어지면 찌부(잠깐 못 움직임). plats 는 around(y). crumbled 는 부서진 발판 id 들. t 는 벽시계 초
 */
export function step(b: Body, inp: Input, dt: number, plats: Platform[], t: number, crumbled: Set<string>): Body {
  let { x, y, vx, vy, on, face, idle, hurt, charge, apex } = b;
  hurt = Math.max(0, hurt - dt);
  const dir = (inp.right ? 1 : 0) - (inp.left ? 1 : 0);
  if (on) {
    if (hurt > 0) { vx = 0; }
    else if (inp.jump) { charge = Math.min(CHARGE, charge + dt); vx = 0; idle = 0; if (dir) face = dir as 1 | -1; }
    else if (charge > 0) {
      // 놓았다 — 뛴다
      vy = JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE);
      vx = dir * RUN; if (dir) face = dir as 1 | -1;
      on = null; charge = 0; idle = 0; apex = y;
    } else {
      const ice = on.kind === 'ice';
      const target = dir * WALK;
      vx = ice ? vx + (target - vx) * Math.min(1, dt * 1.6) : target;
      if (dir) { face = dir as 1 | -1; idle = 0; } else idle += dt;
    }
  }
  if (on?.kind === 'move') x += (platX(on, t) - platX(on, t - dt)); // 실려 간다
  if (!on) { vy -= G * dt; x += windOf(Math.floor(y / BAND_H)) * dt; apex = Math.max(apex, y); }   // 공중: 바람만 민다
  const ny = y + vy * dt;
  x += vx * dt;
  if (x < HW) { x = HW; if (!on) vx = Math.abs(vx) * 0.55; }                   // 벽 튕김
  else if (x > WORLD_W - HW) { x = WORLD_W - HW; if (!on) vx = -Math.abs(vx) * 0.55; }
  let landed: Platform | null = null;
  if (vy <= 0) {
    for (const p of plats) {
      if (crumbled.has(p.id)) continue;
      const px = platX(p, t);
      if (x + HW > px && x - HW < px + p.w && y >= p.y && ny <= p.y) { landed = p; break; }
    }
  }
  if (landed) {
    y = landed.y; on = landed;
    if (landed.kind === 'spring') { vy = JUMP_V * 1.5; on = null; idle = 0; apex = y; }
    else {
      vy = 0; vx = 0;
      if (apex - y > SPLAT) { hurt = 1.1; idle = 0; } // 찌부
      apex = y;
    }
  } else {
    y = ny;
    if (on) { const px = platX(on, t); if (x + HW <= px || x - HW >= px + on.w || crumbled.has(on.id)) { on = null; apex = y; } }
  }
  return { x, y, vx, vy, on, face, idle, hurt, charge, apex };
}
export const poseOf = (b: Body): Pose => (b.hurt > 0 ? 'hurt' : !b.on ? (b.vy > 0 ? 'jump' : 'fall') : b.charge > 0 ? 'charge' : b.idle > 2.5 ? 'sit' : Math.abs(b.vx) > 20 ? 'run' : 'stand');

// ── 주민 NPC ──
export type Role = 'shover' | 'blocker' | 'pacer' | 'rester';
export interface Npc { who: number; role: Role; plat: Platform; k: number; speed: number; phase: number; band: number }

/** 층 n 의 주민들 — 몇 명(0~3), 누구, 무슨 역할, 어느 발판. 방해꾼(shover·blocker)이 다수 — 이 탑에서 주민은 NPC 다 */
export function npcsOf(n: number, residents: number): Npc[] {
  if (n < 3 || residents === 0) return []; // 첫 세 층은 조용하다 — 조작을 익힐 자리
  const r = rng(SEED ^ Math.imul(n + 99, 3266489917));
  const ps = band(n); const std = ps.filter((p) => p.kind === 'std' || p.kind === 'ice');
  // 위로 갈수록 많아진다: 3~10층 0~1명, 30층쯤 1~2명, 80층 위 2~4명
  const dens = Math.min(1, (n - 3) / 80);
  const v0 = r();
  const count = v0 < 0.35 - dens * 0.3 ? 0 : v0 < 0.75 - dens * 0.3 ? 1 : v0 < 0.95 - dens * 0.2 ? 2 : dens > 0.6 && r() < 0.5 ? 4 : 3;
  const out: Npc[] = [];
  const used = new Set<number>();
  for (let i = 0; i < count && std.length; i++) {
    const who = Math.floor(r() * residents);
    if (used.has(who)) continue; used.add(who);
    const v = r();
    const role: Role = v < 0.35 ? 'shover' : v < 0.6 ? 'blocker' : v < 0.8 ? 'pacer' : 'rester';
    const rest = ps.find((p) => p.kind === 'rest');
    const plat = role === 'rester' && rest ? rest : std[Math.floor(r() * std.length)];
    out.push({ who, role, plat, k: r(), speed: 0.4 + r() * 0.5, phase: r() * 6.28, band: n });
  }
  return out;
}
/** NPC 의 지금 위치·자세. shove 는 지금 미는 중인가(주기적으로 0.5초) */
export function npcAt(npc: Npc, t: number): { x: number; y: number; pose: Pose; face: 1 | -1; shove: boolean } {
  const p = npc.plat; const px = platX(p, t);
  const y = p.y;
  if (npc.role === 'rester') return { x: px + p.w * (0.15 + 0.7 * npc.k), y, pose: 'sit', face: npc.k < 0.5 ? 1 : -1, shove: false };
  if (npc.role === 'blocker') {
    // 발판 가장자리(안쪽 방향)에 서서 팔짱 — 닿으면 민다
    const inner = px < WORLD_W / 2 ? px + p.w - 18 : px + 18;
    return { x: inner, y, pose: 'stand', face: px < WORLD_W / 2 ? 1 : -1, shove: true };
  }
  const span = Math.max(0, p.w - 40);
  const s = Math.sin(t * npc.speed * 2 + npc.phase);
  const x = px + 20 + span * (0.5 + 0.5 * s);
  const face: 1 | -1 = Math.cos(t * npc.speed * 2 + npc.phase) >= 0 ? 1 : -1;
  if (npc.role === 'pacer') return { x, y, pose: 'run', face, shove: false };
  // shover: 걷다가 3.5초마다 0.6초 동안 팔을 뻗는다 — 그때 닿으면 날아간다
  const cyc = (t + npc.phase) % 3.5;
  return { x, y, pose: cyc < 0.6 ? 'stand' : 'run', face, shove: cyc < 0.6 };
}
/** 밀림 — 같은 발판, 가까이, 미는 중이면 튕겨 낸다 */
export function shoved(b: Body, n: { x: number; y: number; face: 1 | -1; shove: boolean }): Body | null {
  if (!n.shove || !b.on || Math.abs(b.y - n.y) > 4 || Math.abs(b.x - n.x) > 20 || b.hurt > 0) return null;
  const dir: 1 | -1 = b.x >= n.x ? 1 : -1;
  return { ...b, vx: dir * 420, vy: 260, on: null, hurt: 0.9, idle: 0, charge: 0, apex: b.y };
}
export const metres = (y: number) => Math.round(y / 10);
