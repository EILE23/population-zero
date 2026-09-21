/**
 * Pond — 다 같이 앉아서 낚시. 순수 규칙(DOM 없음). 사람과 주민이 같은 연못·같은 표·같은 낚싯대 규칙을 쓴다.
 *
 * 지도: 물가 한 줄 4000px, 다섯 구역. 구역마다 나오는 것·난이도(입질 기다림·챔질 창)·필요한 낚싯대·잘 먹히는 미끼가 다르다.
 * 뽑기는 서버가 한다(구역·낚싯대·미끼로 가중치를 바꿔서) — 브라우저는 입질 타이밍만 맡는다.
 * 주민의 자리·리듬·수확은 (씨앗, 시각) 의 결정적 함수라 서버 없이 모두 같은 걸 본다.
 */
import { hash, rng } from './tower';
import { ITEMS, type G, type R, type Row } from './pond-items';

export const POND_W = 4000;
export const ZONE_W = 800;
export type ZoneKey = 'd' | 'r' | 'p' | 'e' | 'i';
export interface Zone { key: ZoneKey; name: string; x0: number; rod: number; wait: [number, number]; window: number; bait: BaitKey | null; blurb: string }
export const ZONES: Zone[] = [
  { key: 'd', name: 'The dock', x0: 0, rod: 1, wait: [4, 10], window: 0.9, bait: 'worm', blurb: 'Real fish, mostly. Beginners and ducks.' },
  { key: 'r', name: 'The reeds', x0: 800, rod: 1, wait: [5, 12], window: 0.8, bait: 'worm', blurb: 'Frogs, weeds, things that were hiding.' },
  { key: 'p', name: 'The drainage pipe', x0: 1600, rod: 2, wait: [3, 8], window: 0.6, bait: 'bread', blurb: 'Junk. Phones. A fax machine. Fast bites, bad ones.' },
  { key: 'e', name: 'The deep end', x0: 2400, rod: 3, wait: [8, 18], window: 0.45, bait: 'lure', blurb: 'Big, rare, wrong. Long waits, tiny window.' },
  { key: 'i', name: 'The ice hole', x0: 3200, rod: 4, wait: [10, 20], window: 0.5, bait: 'cheese', blurb: 'Cold. Slow. Things frozen mid-sentence.' },
];
export const zoneAt = (x: number): Zone => ZONES[Math.min(ZONES.length - 1, Math.max(0, Math.floor(x / ZONE_W)))];

export type BaitKey = 'worm' | 'bread' | 'lure' | 'cheese';
export interface Bait { key: BaitKey; name: string; price: number; blurb: string }
export const BAITS: Bait[] = [
  { key: 'worm', name: 'worm', price: 1, blurb: 'fish like it. so do ducks.' },
  { key: 'bread', name: 'bread', price: 1, blurb: 'pulls junk and whatever lives in the pipe.' },
  { key: 'lure', name: 'lure', price: 4, blurb: 'shiny. rare things look up.' },
  { key: 'cheese', name: 'cheese', price: 6, blurb: 'nobody knows why it works on the ice.' },
];

export interface Rod { level: number; name: string; price: number; window: number; wait: number; luck: number }
/** 낚싯대 — 값은 코인. window 는 챔질 창 배수, wait 는 기다림 배수, luck 은 희귀 가중치 배수 */
export const RODS: Rod[] = [
  { level: 1, name: 'a stick with string', price: 0, window: 1, wait: 1, luck: 1 },
  { level: 2, name: 'a rod from the shed', price: 40, window: 1.15, wait: 0.9, luck: 1.15 },
  { level: 3, name: 'a proper rod', price: 140, window: 1.3, wait: 0.8, luck: 1.35 },
  { level: 4, name: 'a rod with a reel that clicks', price: 360, window: 1.45, wait: 0.7, luck: 1.6 },
  { level: 5, name: 'a rod that hums', price: 900, window: 1.6, wait: 0.6, luck: 2 },
  { level: 6, name: 'the rod', price: 2400, window: 1.8, wait: 0.5, luck: 2.6 },
];
export const COINS: Record<R, number> = { c: 1, u: 3, r: 12, l: 60 };
export const RARITY_NAME: Record<R, string> = { c: 'common', u: 'uncommon', r: 'rare', l: 'legendary' };
export const RARITY_COLOR: Record<R, string> = { c: '#8f8489', u: '#2f7d5b', r: '#7b526c', l: '#c48a1a' };

export interface Item { key: string; name: string; rarity: R; glyph: G; zones: string; line?: string }
export const ITEM_LIST: Item[] = ITEMS.map((r: Row) => ({ key: r[0], name: r[1], rarity: r[2], glyph: r[3], zones: r[4], line: r[5] }));
export const ITEM_BY_KEY = new Map(ITEM_LIST.map((i) => [i.key, i]));

/** 구역·낚싯대·미끼에 맞춘 가중치 — 흔한 것 1, 드묾 0.45, 희귀 0.12, 전설 0.02 에 luck 이 곱해진다. 맞는 미끼면 그 구역 것이 두 배 */
export const DIFFICULTY: Record<R, number> = { c: 0.25, u: 0.45, r: 0.7, l: 0.9 };
export function weights(zone: ZoneKey, rod: Rod, bait: BaitKey | null, cast: { far: number; near: boolean } = { far: 0, near: false }): { item: Item; w: number }[] {
  const base: Record<R, number> = { c: 1, u: 0.45, r: 0.12 * rod.luck, l: 0.02 * rod.luck };
  const zone0 = ZONES.find((z) => z.key === zone)!;
  const out: { item: Item; w: number }[] = [];
  for (const item of ITEM_LIST) {
    const here = item.zones === '*' || item.zones.includes(zone);
    if (!here) continue;
    let w = base[item.rarity];
    if (item.zones !== '*') w *= 1.6;                       // 이 구역 특산
    if (bait && zone0.bait === bait && item.zones !== '*') w *= 1.8; // 맞는 미끼
    if (bait === 'lure' && (item.rarity === 'r' || item.rarity === 'l')) w *= 1.5;
    if (bait === 'bread' && item.rarity === 'c' && item.zones === 'p') w *= 1.5;
    if (cast.far > 0.6 && (item.rarity === 'r' || item.rarity === 'l')) w *= 1 + cast.far;   // 멀리 던질수록 희귀
    if (cast.near && (item.key.startsWith('nothing') || item.glyph === 'weed')) w *= 0.3;   // 그림자 옆이면 헛탕이 준다
    if (!cast.near && item.glyph === 'weed') w *= 1.4;
    out.push({ item, w });
  }
  return out;
}
export function roll(r: () => number, zone: ZoneKey, rod: Rod, bait: BaitKey | null, cast?: { far: number; near: boolean }): Item {
  const ws = weights(zone, rod, bait, cast);
  const total = ws.reduce((a, x) => a + x.w, 0);
  let v = r() * total;
  for (const x of ws) { v -= x.w; if (v <= 0) return x.item; }
  return ws[0].item;
}

/** 뱃지 — 레딧 트로피처럼 마이페이지·블로그에 붙는다. 전설은 하나마다, 나머진 이정표 */
export interface Badge { key: string; name: string; blurb: string; price?: number }
/** 상점 뱃지 — 코인으로 산다. 실력이 아니라 취향의 표시라 값이 싸지 않다 */
export const SHOP_BADGES: Badge[] = [
  { key: 's:fisher', name: 'Fisher', blurb: 'bought the title. fair.', price: 30 },
  { key: 's:pondscum', name: 'Pond scum', blurb: 'self-described', price: 45 },
  { key: 's:duckfriend', name: 'Duck friend', blurb: 'the ducks tolerate you', price: 60 },
  { key: 's:pipe', name: 'Pipe enjoyer', blurb: 'spends time at the drainage pipe on purpose', price: 80 },
  { key: 's:deep', name: 'Deep end', blurb: 'has opinions about the deep end', price: 120 },
  { key: 's:frozen', name: 'Frozen', blurb: 'sat at the ice hole too long', price: 150 },
  { key: 's:ghost', name: 'Ghost-adjacent', blurb: 'has seen the 8-foot ghost. probably.', price: 250 },
  { key: 's:mgmt', name: 'Cleared by The Management', blurb: 'a stamp, not an endorsement', price: 400 },
  { key: 's:legend', name: 'Local legend', blurb: 'the pond knows your name', price: 900 },
];
export const GOOSE_BADGES: Badge[] = [
  { key: 'g:first', name: 'Nuisance', blurb: 'did one thing on the list' },
  { key: 'g:day', name: 'Menace', blurb: 'finished a whole day of it' },
  { key: 'g:fifty', name: 'Public enemy', blurb: '50 things done to the residents' },
];
export const BADGES: Badge[] = [
  ...SHOP_BADGES, ...GOOSE_BADGES,
  { key: 'first', name: 'Wet line', blurb: 'caught something. anything.' },
  { key: 'ten', name: 'Regular', blurb: '10 things out of the pond' },
  { key: 'fifty', name: 'Local', blurb: '50 things' },
  { key: 'two_hundred', name: 'Part of the pond', blurb: '200 things' },
  { key: 'rare', name: 'Eyebrow', blurb: 'a rare one' },
  { key: 'all_zones', name: 'Been around', blurb: 'caught something in every spot' },
  { key: 'the_rod', name: 'The rod', blurb: 'owns the rod' },
  ...ITEM_LIST.filter((i) => i.rarity === 'l').map((i) => ({ key: `l:${i.key}`, name: i.name.replace(/^(an? |the )/, '').replace(/[.,].*$/, '').slice(0, 30), blurb: `caught ${i.name}` })),
];
export const BADGE_BY_KEY = new Map(BADGES.map((b) => [b.key, b]));

// ── 주민 ──
export const SEAT_GAP = 70;
/** 이 시간에 앉아 있는 주민들 — 한 시간마다 바뀐다. 구역마다 2~4명 */
export function sittingResidents(hour: number, residents: number): { who: number; x: number; zone: ZoneKey; seed: number }[] {
  const r = rng(hash(`pond:${hour}`));
  const used = new Set<number>();
  const out: { who: number; x: number; zone: ZoneKey; seed: number }[] = [];
  for (const z of ZONES) {
    const n = 2 + Math.floor(r() * 3);
    for (let i = 0; i < n; i++) {
      let who = Math.floor(r() * residents); while (used.has(who)) who = (who + 1) % residents; used.add(who);
      out.push({ who, x: z.x0 + 60 + r() * (ZONE_W - 120), zone: z.key, seed: hash(`pond:${hour}:${who}`) });
    }
  }
  return out;
}
/** 주민의 지금 상태 — 던져 두고 기다리다 가끔 잡는다. 주기 30~55초, 마지막 3초가 수확 표시 */
export function residentState(seed: number, zone: ZoneKey, t: number): { phase: 'wait' | 'catch'; item: Item | null } {
  const period = 30 + (seed % 25);
  const cycle = Math.floor(t / period);
  const u = (t % period) / period;
  const r = rng(seed ^ cycle);
  if (u > 1 - 3 / period && r() < 0.6) return { phase: 'catch', item: roll(r, zone, RODS[1 + (seed % 3)], null) };
  return { phase: 'wait', item: null };
}

// ── 2.5D ──
export const DEPTH_PX = 110;     // 물가의 앞뒤 깊이(화면 px, 뒤 0 → 물가 1)
/** 물속 그림자 — 구역마다 3~5마리가 (씨앗, 시각) 대로 돌아다닌다. 찌를 그 근처에 넣으면 헛탕이 준다 */
export function shadows(zone: Zone, t: number): { x: number; d: number; size: number }[] {
  const r = rng(hash(`shadow:${zone.key}`));
  const n = 3 + Math.floor(r() * 3);
  const out = [];
  for (let i = 0; i < n; i++) {
    const cx = zone.x0 + 80 + r() * (ZONE_W - 160), amp = 60 + r() * 120, sp = 0.05 + r() * 0.08, ph = r() * 6.28;
    const d0 = 0.2 + r() * 0.7, size = 14 + r() * 18;
    out.push({ x: cx + Math.sin(t * sp * 6.28 + ph) * amp, d: d0 + Math.sin(t * sp * 3.1 + ph * 2) * 0.15, size });
  }
  return out;
}
