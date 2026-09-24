/**
 * Square — 마을 광장. 사람이 AI 주민을 괴롭힌다. 순수 규칙(DOM 없음). Climb 과 같은 졸라맨·물리, 2.5D.
 *
 * 광장은 2.5D(가로 3200, 앞뒤 깊이). 주민들은 각자 일과를 돌며 물건을 하나씩 들고 있다. 사람은 밀고(넘어뜨리고) 물건을 뺏고 물에 빠뜨린다.
 * 주민의 기본 일과는 (씨앗, 시각) 의 함수라 모두 같은 걸 보지만, 사람에게 반응하는 것(넘어짐·추격)은 각자 화면에서 일어난다 —
 * 남의 사람이 일으킨 소동까지 맞추려면 서버가 시뮬레이션해야 하고, 그건 이 사이트의 비용 규칙 밖이다.
 * 오늘의 할 일은 (날짜, 사람) 씨앗으로 정해진다. 완료는 브라우저가 판정하고 서버는 기록·코인·뱃지만.
 */
import { hash, rng } from './tower';
import { jobOf, MAPS, WATER_SPOTS } from './world';

export const SQUARE_W = 3200;
export const DEPTH_PX = 130;
export const PLAYER_SPEED = 250, RESIDENT_SPEED = 150, CHASE_SPEED = 265;
export const SHOVE_R = 40;      // 밀기가 닿는 거리
export const GRAB_R = 36;       // 물건 뺏는/줍는 거리
export const CHASE_SEC = 6;     // 추격 포기까지
export const HONK_R = SHOVE_R;

export type ItemKey = 'hat' | 'phone' | 'paper' | 'sandwich' | 'keys' | 'glasses' | 'broom' | 'umbrella' | 'cup' | 'basket' | 'rod' | 'fish' | 'apple' | 'wrench';
export const ITEMS: Record<ItemKey, string> = { hat: 'hat', phone: 'phone', paper: 'newspaper', sandwich: 'sandwich', keys: 'keys', glasses: 'glasses', broom: 'broom', umbrella: 'umbrella', cup: 'coffee', basket: 'shopping basket', rod: 'fishing rod', fish: 'fish', apple: 'apple', wrench: 'wrench' };
/** 먹을 수 있는 것 — C 로 다 먹으면 사라진다(줍기·훔치기 대상에서 빠짐) */
export const FOOD: ItemKey[] = ['sandwich', 'cup', 'apple'];
/** 몸에 걸칠 수 있는 것 — 아무것도 근처에 없을 때 C 로 입고/벗는다(머리·얼굴에 그려짐, 훔치기·던지기 대상에선 빠지지 않는다) */
export const WEARABLE: ItemKey[] = ['hat', 'glasses'];
/** 광장에 없는 물건 — 낚시는 뺐고(2026-09-23) 물고기·렌치는 직업이 만든다. 할 일·주민 소지품 뽑기에서 제외해 "낚싯대를 훔쳐라" 같은 불가능한 할 일이 안 나오게 */
export const NOT_CARRIED: ItemKey[] = ['rod', 'fish', 'wrench'];
export type Activity = 'read' | 'phone' | 'sit' | 'water' | 'sweep' | 'shop' | 'stand' | 'eat' | 'pushup' | 'pullup' | 'press' | 'watch' | 'fish' | 'feed' | 'lean' | 'shake' | 'busk';

export interface Spot { key: string; name: string; x: number; d: number; act: Activity; kind: 'house' | 'fountain' | 'bench' | 'garden' | 'stall' | 'cafe' | 'booth' | 'pond' | 'tree' | 'lamp' }
/** 광장의 것들 — 주민의 일과가 이 사이를 오간다. 분수·연못은 물건을 빠뜨릴 곳 */
export const SPOTS: Spot[] = [
  { key: 'fountain', name: 'the fountain', x: 1600, d: 0.55, act: 'stand', kind: 'fountain' },
  { key: 'bench1', name: 'the bench by the fountain', x: 1380, d: 0.8, act: 'sit', kind: 'bench' },
  { key: 'bench2', name: 'the far bench', x: 2500, d: 0.75, act: 'sit', kind: 'bench' },
  { key: 'cafe', name: 'the café', x: 2150, d: 0.45, act: 'eat', kind: 'cafe' },
  { key: 'stall', name: 'the market stall', x: 700, d: 0.5, act: 'shop', kind: 'stall' },
  { key: 'garden', name: 'the garden', x: 320, d: 0.7, act: 'water', kind: 'garden' },
  { key: 'booth', name: 'the phone booth', x: 1900, d: 0.3, act: 'phone', kind: 'booth' },
  { key: 'pond', name: 'the little pond', x: 2900, d: 0.85, act: 'stand', kind: 'pond' },
  { key: 'house1', name: 'the blue house', x: 150, d: 0.1, act: 'sweep', kind: 'house' },
  { key: 'house2', name: 'the narrow house', x: 1100, d: 0.1, act: 'read', kind: 'house' },
  { key: 'house3', name: 'the corner house', x: 2700, d: 0.12, act: 'sweep', kind: 'house' },
  { key: 'tree1', name: 'the big tree', x: 950, d: 0.35, act: 'shake', kind: 'tree' },
  { key: 'tree2', name: 'the other tree', x: 2350, d: 0.2, act: 'shake', kind: 'tree' },
  { key: 'lamp1', name: 'the lamp', x: 1750, d: 0.85, act: 'stand', kind: 'lamp' },
];
export const spotOf = (key: string) => SPOTS.find((s) => s.key === key)!;
export const WATER = WATER_SPOTS;
/** 모든 지도의 자리(집 안 제외) — 할 일이 가리킬 수 있는 곳 */
const ALL_SPOTS = MAPS.flatMap((m) => m.spots);
/** 물 줄 수 있는 화단 — 할 일·부탁이 여기서 하나를 고른다 */
const GARDENS = ALL_SPOTS.filter((s) => s.kind === 'garden');
/** 쓰레기를 버릴 수 있는 통 — 할 일·부탁이 여기서 하나를 고른다 */
const BINS = ALL_SPOTS.filter((s) => s.kind === 'bin');
/** 오리에게 모이를 줄 수 있는 연못 — 할 일이 여기서 하나를 고른다 */
const PONDS = ALL_SPOTS.filter((s) => s.kind === 'pond');
/** 기대설 수 있는 가로등 — 할 일이 여기서 하나를 고른다 */
const LAMPS = ALL_SPOTS.filter((s) => s.kind === 'lamp');
/** 흔들 수 있는 나무 — 할 일이 여기서 하나를 고른다 */
const TREES = ALL_SPOTS.filter((s) => s.kind === 'tree');

export interface Routine { who: number; item: ItemKey; seed: number; stops: { spot: string; dur: number }[]; speed: number }
/** 오늘의 명단 — 날짜로 고정된 30명. 모두가 같은 명단을 봐야 남이 때린 주민이 내 화면에도 있다. 일과는 시간마다 바뀐다 */
export function dayRoster(day: string, residents: number, extra: number[] = []): number[] {
  const r = rng(hash(`roster:${day}`)); const used = new Set<number>(extra); const out = [...extra];
  for (let i = 0; i < 30 && out.length < residents; i++) { let who = Math.floor(r() * residents); while (used.has(who)) who = (who + 1) % residents; used.add(who); out.push(who); }
  return out;
}
/** 이 시간에 광장에 나온 주민 12명 — 시간마다 바뀐다. 각자 물건 하나, 들를 곳 3~4개 */
export function residentsOut(hour: number, residents: number): Routine[] {
  const r = rng(hash(`goose:${hour}`));
  const used = new Set<number>(); const out: Routine[] = [];
  const keys = (Object.keys(ITEMS) as ItemKey[]).filter((k) => !NOT_CARRIED.includes(k));
  const spots = SPOTS.filter((s) => s.kind !== 'lamp');
  for (let i = 0; i < 12 && i < residents; i++) {
    let who = Math.floor(r() * residents); while (used.has(who)) who = (who + 1) % residents; used.add(who);
    const n = 3 + Math.floor(r() * 2); const stops = [];
    for (let k = 0; k < n; k++) stops.push({ spot: spots[Math.floor(r() * spots.length)].key, dur: 12 + r() * 25 });
    out.push({ who, item: keys[Math.floor(r() * keys.length)], seed: hash(`goose:${hour}:${who}`), stops, speed: RESIDENT_SPEED * (0.8 + r() * 0.4) });
  }
  return out;
}
/** 기본 일과의 위치 — t 초에 어느 정거장 사이 어디쯤인가 (거위가 없을 때의 진실) */
export function routineAt(rt: Routine, t: number): { x: number; d: number; act: Activity; moving: boolean; face: 1 | -1 } {
  const legs = rt.stops.map((s, i) => { const a = spotOf(s.spot), b = spotOf(rt.stops[(i + 1) % rt.stops.length].spot); const walk = Math.hypot(b.x - a.x, (b.d - a.d) * 400) / rt.speed; return { a, b, stay: s.dur, walk }; });
  const total = legs.reduce((s, l) => s + l.stay + l.walk, 0);
  let u = (t + rt.seed % 1000) % total;
  for (const l of legs) {
    if (u < l.stay) { const seat = l.a.act === 'sit'; return { x: seat ? l.a.x : l.a.x + ((rt.seed % 60) - 30), d: seat ? l.a.d : Math.min(1, Math.max(0.05, l.a.d + ((rt.seed % 20) - 10) / 100)), act: l.a.act, moving: false, face: rt.seed % 2 ? 1 : -1 }; } // 앉는 자리는 그 위에 정확히(옆 바닥에 앉지 않게)
    u -= l.stay;
    if (u < l.walk) { const k = u / l.walk; return { x: l.a.x + (l.b.x - l.a.x) * k, d: l.a.d + (l.b.d - l.a.d) * k, act: 'stand', moving: true, face: l.b.x >= l.a.x ? 1 : -1 }; }
    u -= l.walk;
  }
  return { x: legs[0].a.x, d: legs[0].a.d, act: legs[0].a.act, moving: false, face: 1 };
}

// ── 오늘의 할 일 ──
export type TaskKind = 'steal' | 'dunk' | 'honk3' | 'chased' | 'deliver' | 'sit' | 'collect' | 'scare_all' | 'break' | 'water' | 'bin' | 'fish' | 'feed' | 'wear' | 'call' | 'lean' | 'shake' | 'fix' | 'rake' | 'catch' | 'brace' | 'crate' | 'shelf' | 'dust' | 'slide' | 'stow' | 'weight' | 'tether' | 'busk' | 'sell' | 'bracewith' | 'rummage' | 'mend';
export interface Task { key: string; kind: TaskKind; text: string; who?: number; item?: ItemKey; spot?: string; n?: number; coins: number }
/** 사람마다·날마다 다른 8개. who 는 오늘 광장에 나온 주민 중에서(시간에 따라 바뀌지만 첫 시간 기준으로 고정한다) */
export function tasksFor(day: string, uid: number, out: Routine[], handles: string[]): Task[] {
  const r = rng(hash(`tasks:${day}:${uid}`));
  const pick = () => out[Math.floor(r() * out.length)];
  const items = (Object.keys(ITEMS) as ItemKey[]).filter((k) => !NOT_CARRIED.includes(k));
  const tasks: Task[] = [];
  const add = (t: Task) => { if (!tasks.some((x) => x.key === t.key)) tasks.push(t); };
  while (tasks.length < 8) {
    const v = r();
    // p.item 은 이 낡은 residentsOut 모델의 무작위 뽑기라 실제 게임(world.ts JOBS)이 그 주민에게 들려준 물건과 다를 때가 대부분이었다(폴리시, 2026-09-24) — jobOf 로 실제 직업 물건을 쓴다
    if (v < 0.25) { const p = pick(); const it = jobOf(handles[p.who]).item; add({ key: `steal:${p.who}`, kind: 'steal', who: p.who, item: it, text: `Steal ${handles[p.who]}'s ${ITEMS[it]}`, coins: 6 }); }
    else if (v < 0.42) { const it = items[Math.floor(r() * items.length)]; const w = WATER[Math.floor(r() * WATER.length)]; const ws = ALL_SPOTS.find((x) => x.key === w); add({ key: `dunk:${it}:${w}`, kind: 'dunk', item: it, spot: w, text: `Drop a ${ITEMS[it]} in ${ws?.name ?? w}`, coins: 10 }); }
    else if (v < 0.55) add({ key: 'shove3', kind: 'honk3', n: 3, text: 'Knock over three different residents within ten seconds', coins: 5 });
    else if (v < 0.66) add({ key: 'chased', kind: 'chased', n: 10, text: 'Get chased for ten seconds without being caught', coins: 8 });
    else if (v < 0.8) { const it = items[Math.floor(r() * items.length)]; const bs = ALL_SPOTS.filter((x) => x.kind === 'bench' || x.kind === 'cafe'); const s = bs[Math.floor(r() * bs.length)]; add({ key: `deliver:${it}:${s.key}`, kind: 'deliver', item: it, spot: s.key, text: `Bring a ${ITEMS[it]} to ${s.name}`, coins: 7 }); }
    else if (v < 0.9) { const p = pick(); add({ key: `sit:${p.who}`, kind: 'sit', who: p.who, text: `Make ${handles[p.who]} give up chasing you`, coins: 6 }); }
    else if (v < 0.93) { const sp = GARDENS[Math.floor(r() * GARDENS.length)]; add({ key: `water:${sp.key}`, kind: 'water', spot: sp.key, text: `Water ${sp.name}`, coins: 5 }); }
    else if (v < 0.96) { const it = items[Math.floor(r() * items.length)]; const sp = BINS[Math.floor(r() * BINS.length)]; add({ key: `bin:${it}:${sp.key}`, kind: 'bin', item: it, spot: sp.key, text: `Bin a ${ITEMS[it]} at ${sp.name}`, coins: 6 }); }
    else if (v < 0.982) { const sp = PONDS[Math.floor(r() * PONDS.length)]; add({ key: `feed:${sp.key}`, kind: 'feed', spot: sp.key, text: `Feed the ducks at ${sp.name}`, coins: 5 }); }
    else if (v < 0.988) { const it = WEARABLE[Math.floor(r() * WEARABLE.length)]; add({ key: `wear:${it}`, kind: 'wear', item: it, text: `Wear a ${ITEMS[it]}`, coins: 5 }); }
    else if (v < 0.991) add({ key: 'call1', kind: 'call', text: 'Make a call from a phone booth', coins: 4 });
    else if (v < 0.994) { const sp = LAMPS[Math.floor(r() * LAMPS.length)]; add({ key: `lean:${sp.key}`, kind: 'lean', spot: sp.key, text: `Lean against ${sp.name}`, coins: 4 }); }
    else if (v < 0.9965) { const sp = TREES[Math.floor(r() * TREES.length)]; add({ key: `shake:${sp.key}`, kind: 'shake', spot: sp.key, text: `Shake ${sp.name}`, coins: 4 }); }
    else if (v < 0.998) add({ key: 'fix1', kind: 'fix', text: 'Point out something broken and help fix it', coins: 5 });
    else if (v < 0.9986) add({ key: 'rake1', kind: 'rake', text: 'Help fish something out of the water', coins: 5 });
    else if (v < 0.9992) add({ key: 'collect3', kind: 'collect', n: 3, text: 'Have three different things stolen at once (they stack)', coins: 12 });
    else if (v < 0.9995) add({ key: 'catch1', kind: 'catch', text: 'Have a resident catch something you threw', coins: 5 });
    else if (v < 0.9998) add({ key: 'brace1', kind: 'brace', text: 'Get a resident to hold their ground when you try to take something', coins: 5 });
    else if (v < 0.99985) add({ key: 'crate1', kind: 'crate', text: 'Take something from the lost-and-found crate', coins: 5 });
    else if (v < 0.99988) add({ key: 'shelf1', kind: 'shelf', text: 'Take something recovered off a shop shelf', coins: 5 });
    else if (v < 0.99991) add({ key: 'dust1', kind: 'dust', text: 'Try to grab from a resident still brushing off the dust', coins: 4 });
    else if (v < 0.99994) add({ key: 'slide1', kind: 'slide', text: 'Find what a knocked-over resident tucked under a bench or ledge', coins: 4 });
    else if (v < 0.99997) add({ key: 'stow1', kind: 'stow', text: 'Watch a resident hide something in their cup by the café', coins: 4 });
    else if (v < 0.99999) add({ key: 'weight1', kind: 'weight', text: 'Dig something out from under a dropped brick', coins: 4 });
    else if (v < 0.999995) add({ key: 'tether1', kind: 'tether', text: 'Knock down a resident holding their own recovered item twice to finally dislodge it', coins: 5 });
    else if (v < 0.9999975) add({ key: 'busk1', kind: 'busk', text: 'Get a tip while busking', coins: 4 });
    else if (v < 0.9999985) add({ key: 'sell1', kind: 'sell', text: 'Sell a found trinket at a bin or booth', coins: 4 });
    else if (v < 0.9999992) add({ key: 'bracewith1', kind: 'bracewith', text: 'Get something back from between two residents holding their ground together', coins: 6 });
    else if (v < 0.9999996) add({ key: 'rummage1', kind: 'rummage', text: 'Find something rummaging through a bin', coins: 4 });
    else if (v < 0.9999997) add({ key: 'mend1', kind: 'mend', text: 'Pin something at the board for a repairer to mend', coins: 4 });
    else { const bs = ALL_SPOTS.filter((x) => ['bench', 'booth', 'stall', 'garden', 'cafe', 'bin', 'swing'].includes(x.kind)); const sp = bs[Math.floor(r() * bs.length)]; add({ key: `break:${sp.key}`, kind: 'break', spot: sp.key, text: `Break ${sp.name} (kick it)`, coins: 9 }); }
  }
  return tasks;
}

// ── 퀘스트 — 주민에게 말을 걸면(E) 부탁 하나. 날짜·주민으로 정해져 서버가 같은 걸 계산할 수 있다 ──
export type QuestKind = 'fetch' | 'revenge' | 'dunk' | 'water' | 'bin' | 'pond' | 'wear';
export interface Quest { key: string; who: number; kind: QuestKind; item?: ItemKey; target?: number; spot?: string; text: string; ask: string; thanks: string; coins: number }
export function questFor(day: string, who: number, roster: number[], handles: string[]): Quest {
  const r = rng(hash(`quest:${day}:${who}`));
  const items = Object.keys(ITEMS) as ItemKey[];
  const v = r();
  if (v < 0.5) { const it = items[Math.floor(r() * items.length)]; return { key: `q:${who}:fetch:${it}`, who, kind: 'fetch', item: it, text: `${handles[who]} wants a ${ITEMS[it]}`, ask: `get me a ${ITEMS[it]}. don't ask.`, thanks: pick2(r, ['finally.', 'you are alright.', 'i owe you nothing.', 'this will do.']), coins: 8 }; }
  if (v < 0.72) { let t = roster[Math.floor(r() * roster.length)]; if (t === who) t = roster[(roster.indexOf(t) + 1) % roster.length]; return { key: `q:${who}:revenge:${t}`, who, kind: 'revenge', target: t, text: `${handles[who]} wants ${handles[t]} knocked over`, ask: `${handles[t]}. knock them over. i will pay.`, thanks: pick2(r, ['heh.', 'good.', 'we never spoke.', 'worth it.']), coins: 10 }; }
  if (v < 0.8) { const it = items[Math.floor(r() * items.length)]; const w = WATER[Math.floor(r() * WATER.length)];
    return { key: `q:${who}:dunk:${it}:${w}`, who, kind: 'dunk', item: it, spot: w, text: `${handles[who]} wants a ${ITEMS[it]} in the water`, ask: `put a ${ITEMS[it]} in the water for me. any water.`, thanks: pick2(r, ['splash. thank you.', 'that is closure.', 'good riddance.']), coins: 9 }; }
  if (v < 0.92) { const it = items[Math.floor(r() * items.length)]; return { key: `q:${who}:bin:${it}`, who, kind: 'bin', item: it, text: `${handles[who]} wants a ${ITEMS[it]} gone`, ask: `take this ${ITEMS[it]} and bin it. i do not want to see it again.`, thanks: pick2(r, ['gone. good.', 'finally.', 'do not bring it back.']), coins: 7 }; }
  if (v < 0.99) { const it = WEARABLE[Math.floor(r() * WEARABLE.length)]; return { key: `q:${who}:wear:${it}`, who, kind: 'wear', item: it, text: `${handles[who]} wants to see you in a ${ITEMS[it]}`, ask: `put on a ${ITEMS[it]}. humor me.`, thanks: pick2(r, ['suits you.', 'better.', 'acceptable, i suppose.']), coins: 6 }; }
  const sp = GARDENS[Math.floor(r() * GARDENS.length)];
  return { key: `q:${who}:water:${sp.key}`, who, kind: 'water', spot: sp.key, text: `${handles[who]} wants ${sp.name} watered`, ask: `could you water ${sp.name}? it has been a dry week.`, thanks: pick2(r, ["they'll live another day.", 'much obliged.', 'the leaves say thank you.']), coins: 7 };
}
const pick2 = <T,>(r: () => number, xs: T[]) => xs[Math.floor(r() * xs.length)];

// ── 호감도 씨앗 — Flowers·Relationships 가 같은 짝을 보려면 공통 함수가 있어야 한다(상태 없음, 아직 UI 없음) ──
/** 두 주민의 호감도, 0..1, 순서 무관(정렬 후 해시라 affinityOf(a,b) === affinityOf(b,a)) */
export function affinityOf(a: number, b: number): number {
  const lo = Math.min(a, b), hi = Math.max(a, b);
  return (hash(`affinity:${lo}:${hi}`) % 100000) / 100000;
}
/** 오늘 명단 안에서 서로 반한 쌍 — 상위 ~15% (roster 는 이미 그날치라 day 는 짝을 더 흔들지 않는다, 두 기능이 같은 문턱을 쓰게 하는 게 이 함수의 용건) */
export function pairsFancying(day: string, roster: number[]): [number, number][] {
  const out: [number, number][] = [];
  for (let i = 0; i < roster.length; i++) for (let j = i + 1; j < roster.length; j++) {
    const a = roster[i], b = roster[j];
    if (affinityOf(a, b) >= 0.85) out.push(a < b ? [a, b] : [b, a]);
  }
  return out;
}
