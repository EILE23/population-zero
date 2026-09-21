/**
 * Square 의 세계 — 지도 여러 장(광장·시장 거리·공원·집 안)과 주민의 직업. 전부 데이터라 순찰(AI)이 늘릴 수 있다.
 *
 * 지도: 각각 2.5D 한 장. 출구(exit)로 이어진다 — 집 문으로 들어가면 그 집 안 지도, 안에서 문으로 나오면 광장.
 * 직업: 주민마다 하나(핸들 씨앗). 직업이 일과 자리·들고 다니는 물건·반응을 정한다. 경찰은 쫓아와서 벌금을 물린다.
 */
import { hash, rng } from './tower';
import type { Activity, ItemKey } from './goose';

export type PropKind = 'house' | 'fountain' | 'bench' | 'garden' | 'stall' | 'cafe' | 'booth' | 'pond' | 'tree' | 'lamp'
  | 'bed' | 'table' | 'tv' | 'fridge' | 'plant' | 'shelf' | 'door' | 'sofa' | 'bakery' | 'post' | 'station' | 'church' | 'gate' | 'swing' | 'bin';
export interface Spot { key: string; name: string; x: number; d: number; act: Activity; kind: PropKind; owner?: number }
export interface Exit { x: number; d: number; to: string; toX: number; toD: number; label: string }
export interface GameMap { key: string; name: string; w: number; indoor: boolean; floor: [string, string]; spots: Spot[]; exits: Exit[]; owner?: number }

const houseInterior = (key: string, name: string, owner: number | undefined, back: { to: string; x: number }): GameMap => ({
  key, name, w: 960, indoor: true, owner, floor: ['#d9cfc4', '#efe6da'],
  spots: [
    { key: `${key}:bed`, name: 'the bed', x: 160, d: 0.35, act: 'sit', kind: 'bed', owner },
    { key: `${key}:table`, name: 'the kitchen table', x: 480, d: 0.6, act: 'eat', kind: 'table', owner },
    { key: `${key}:tv`, name: 'the TV', x: 780, d: 0.25, act: 'stand', kind: 'tv', owner },
    { key: `${key}:sofa`, name: 'the sofa', x: 700, d: 0.7, act: 'sit', kind: 'sofa', owner },
    { key: `${key}:fridge`, name: 'the fridge', x: 320, d: 0.2, act: 'eat', kind: 'fridge', owner },
    { key: `${key}:plant`, name: 'a houseplant', x: 880, d: 0.85, act: 'water', kind: 'plant', owner },
    { key: `${key}:shelf`, name: 'the bookshelf', x: 60, d: 0.75, act: 'read', kind: 'shelf', owner },
    { key: `${key}:door`, name: 'the front door', x: 480, d: 0.98, act: 'stand', kind: 'door', owner },
  ],
  exits: [{ x: 480, d: 0.97, to: back.to, toX: back.x, toD: 0.3, label: 'out' }],
});

export const MAPS: GameMap[] = [
  {
    key: 'square', name: 'The square', w: 3200, indoor: false, floor: ['#cfc7c2', '#e6e0da'],
    spots: [
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
      { key: 'tree1', name: 'the big tree', x: 950, d: 0.35, act: 'read', kind: 'tree' },
      { key: 'tree2', name: 'the other tree', x: 2350, d: 0.2, act: 'stand', kind: 'tree' },
      { key: 'bin1', name: 'a bin', x: 1250, d: 0.9, act: 'stand', kind: 'bin' },
    ],
    exits: [
      { x: 150, d: 0.12, to: 'house1', toX: 480, toD: 0.9, label: 'the blue house' },
      { x: 1100, d: 0.12, to: 'house2', toX: 480, toD: 0.9, label: 'the narrow house' },
      { x: 2700, d: 0.14, to: 'house3', toX: 480, toD: 0.9, label: 'the corner house' },
      { x: 3190, d: 0.5, to: 'street', toX: 30, toD: 0.5, label: 'Market street →' },
      { x: 10, d: 0.5, to: 'park', toX: 2370, toD: 0.5, label: '← The park' },
    ],
  },
  {
    key: 'street', name: 'Market street', w: 2400, indoor: false, floor: ['#c9c2bd', '#e0d9d3'],
    spots: [
      { key: 'bakery', name: 'the bakery', x: 300, d: 0.1, act: 'shop', kind: 'bakery' },
      { key: 'post', name: 'the post office', x: 900, d: 0.1, act: 'stand', kind: 'post' },
      { key: 'station', name: 'the police station', x: 1500, d: 0.1, act: 'stand', kind: 'station' },
      { key: 'church', name: 'the church', x: 2100, d: 0.08, act: 'sit', kind: 'church' },
      { key: 'stall2', name: 'the fish stall', x: 600, d: 0.6, act: 'shop', kind: 'stall' },
      { key: 'stall3', name: 'the fruit stall', x: 1200, d: 0.65, act: 'shop', kind: 'stall' },
      { key: 'bench3', name: 'the bench outside the bakery', x: 420, d: 0.85, act: 'sit', kind: 'bench' },
      { key: 'booth2', name: 'the other phone booth', x: 1800, d: 0.5, act: 'phone', kind: 'booth' },
      { key: 'bin2', name: 'a bin', x: 1000, d: 0.9, act: 'stand', kind: 'bin' },
      { key: 'bin3', name: 'another bin', x: 2000, d: 0.9, act: 'stand', kind: 'bin' },
    ],
    exits: [{ x: 10, d: 0.5, to: 'square', toX: 3170, toD: 0.5, label: '← The square' }],
  },
  {
    key: 'park', name: 'The park', w: 2400, indoor: false, floor: ['#b9c39e', '#d6dcbc'],
    spots: [
      { key: 'gate', name: 'the park gate', x: 2300, d: 0.5, act: 'stand', kind: 'gate' },
      { key: 'swing', name: 'the swings', x: 600, d: 0.6, act: 'sit', kind: 'swing' },
      { key: 'pond2', name: 'the duck pond', x: 1400, d: 0.8, act: 'stand', kind: 'pond' },
      { key: 'bench4', name: 'the park bench', x: 1000, d: 0.75, act: 'sit', kind: 'bench' },
      { key: 'bench5', name: 'the bench by the pond', x: 1700, d: 0.7, act: 'read', kind: 'bench' },
      { key: 'garden2', name: 'the flower beds', x: 300, d: 0.4, act: 'water', kind: 'garden' },
      { key: 'ptree1', name: 'an oak', x: 800, d: 0.15, act: 'stand', kind: 'tree' },
      { key: 'ptree2', name: 'a willow', x: 1900, d: 0.2, act: 'read', kind: 'tree' },
      { key: 'bin4', name: 'a bin', x: 1200, d: 0.95, act: 'stand', kind: 'bin' },
    ],
    exits: [{ x: 2390, d: 0.5, to: 'square', toX: 40, toD: 0.5, label: 'The square →' }],
  },
];
export const MAP_BY_KEY = new Map(MAPS.map((m) => [m.key, m]));
export const WATER_SPOTS = ['fountain', 'pond', 'pond2'];
export const BREAKABLE: PropKind[] = ['bench', 'lamp', 'booth', 'stall', 'garden', 'cafe', 'bin', 'tv', 'table', 'shelf', 'plant', 'swing', 'sofa'];
/** 앉거나 누울 수 있는 것 — 사람도 주민도 여기서 'sit' 자세(사실은 눕는 자세)를 쓴다 */
export const SITTABLE: PropKind[] = ['bench', 'sofa', 'bed', 'swing'];

/** 집 안 지도 — 세 집은 주인이 있다(핸들 씨앗으로 정한 주민). 주인이 집에 있을 때 들어가면 화를 낸다 */
export function houses(residents: number): GameMap[] {
  const r = rng(hash('houses'));
  const owners = [Math.floor(r() * residents), Math.floor(r() * residents), Math.floor(r() * residents)];
  return [
    houseInterior('house1', 'The blue house', owners[0], { to: 'square', x: 150 }),
    houseInterior('house2', 'The narrow house', owners[1], { to: 'square', x: 1100 }),
    houseInterior('house3', 'The corner house', owners[2], { to: 'square', x: 2700 }),
  ];
}

// ── 직업 ──
export type JobKey = 'baker' | 'postie' | 'cop' | 'gardener' | 'barista' | 'grocer' | 'jogger' | 'busker' | 'dogwalker' | 'sweeper' | 'priest' | 'office' | 'painter' | 'kid' | 'retired' | 'courier' | 'mayor';
export interface Job { key: JobKey; name: string; item: ItemKey; spots: string[]; act: Activity; speed: number; temper: number; line: string }
/** 직업표 — 일과 자리(어느 지도의 어느 곳이든), 물건, 걸음, 성깔(0~1: 맞았을 때 되갚을 확률) */
export const JOBS: Job[] = [
  { key: 'baker', name: 'baker', item: 'basket', spots: ['bakery', 'stall', 'bench3'], act: 'shop', speed: 0.9, temper: 0.4, line: 'the bread is not for you' },
  { key: 'postie', name: 'postal worker', item: 'paper', spots: ['post', 'house1', 'house2', 'house3', 'booth'], act: 'stand', speed: 1.2, temper: 0.3, line: 'that is federal property. probably.' },
  { key: 'cop', name: 'police officer', item: 'cup', spots: ['station', 'fountain', 'street', 'gate'], act: 'stand', speed: 1.3, temper: 1, line: 'stop right there' },
  { key: 'gardener', name: 'gardener', item: 'broom', spots: ['garden', 'garden2', 'plant'], act: 'water', speed: 0.8, temper: 0.5, line: 'those took months' },
  { key: 'barista', name: 'barista', item: 'cup', spots: ['cafe', 'bench1'], act: 'eat', speed: 1, temper: 0.35, line: 'oat milk is extra' },
  { key: 'grocer', name: 'grocer', item: 'basket', spots: ['stall', 'stall2', 'stall3'], act: 'shop', speed: 0.9, temper: 0.6, line: 'you break it you buy it' },
  { key: 'jogger', name: 'jogger', item: 'phone', spots: ['gate', 'pond2', 'fountain', 'street'], act: 'stand', speed: 1.6, temper: 0.2, line: 'my split, come on' },
  { key: 'busker', name: 'busker', item: 'hat', spots: ['fountain', 'bench2', 'gate'], act: 'stand', speed: 0.9, temper: 0.3, line: 'tips go in the hat, not the hat in the fountain' },
  { key: 'dogwalker', name: 'dog walker', item: 'keys', spots: ['park', 'pond2', 'bench4', 'square'], act: 'stand', speed: 1.1, temper: 0.4, line: 'he is a rescue' },
  { key: 'sweeper', name: 'street sweeper', item: 'broom', spots: ['bin1', 'bin2', 'bin3', 'bin4', 'square'], act: 'sweep', speed: 0.85, temper: 0.7, line: 'i JUST did this' },
  { key: 'priest', name: 'priest', item: 'paper', spots: ['church', 'bench3', 'square'], act: 'read', speed: 0.8, temper: 0.1, line: 'i forgive you. reluctantly.' },
  { key: 'office', name: 'office worker', item: 'phone', spots: ['booth', 'booth2', 'cafe', 'bench1'], act: 'phone', speed: 1.1, temper: 0.5, line: 'i am on a call' },
  { key: 'painter', name: 'painter', item: 'umbrella', spots: ['ptree1', 'ptree2', 'fountain'], act: 'stand', speed: 0.8, temper: 0.3, line: 'the light was perfect' },
  { key: 'kid', name: 'kid', item: 'sandwich', spots: ['swing', 'pond2', 'stall3'], act: 'sit', speed: 1.4, temper: 0.9, line: 'i am telling' },
  { key: 'retired', name: 'retired', item: 'glasses', spots: ['bench2', 'bench4', 'bench5', 'church'], act: 'sit', speed: 0.6, temper: 0.2, line: 'in my day' },
  { key: 'courier', name: 'courier', item: 'basket', spots: ['post', 'house1', 'house3', 'cafe', 'bakery'], act: 'stand', speed: 1.5, temper: 0.4, line: 'sign here' },
  { key: 'mayor', name: 'the mayor', item: 'hat', spots: ['fountain', 'church', 'station'], act: 'stand', speed: 0.9, temper: 0.8, line: 'this is going in the minutes' },
];
export const jobOf = (handle: string): Job => JOBS[hash(`job:${handle}`) % JOBS.length];
export const JOB_BY_KEY = new Map(JOBS.map((j) => [j.key, j]));
