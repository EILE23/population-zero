// SVG 에셋 생성기 — 텍스트로 만드는 그림. `node game/tools/assets.mjs` 가 assets/svg/<category>/<name>.svg 와 assets/manifest.json 을 다시 쓴다.
// 규칙은 assets/README.md. 원점은 발끝(바닥 중앙), viewBox = "-w/2 -h w h". 색은 palette.json 의 것만(린트가 막는다).
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets');
const P = JSON.parse(readFileSync(join(ROOT, 'palette.json'), 'utf8'));
const INK = P['ink-soft'], LW = 2.4, FINE = 1.6;

// ── 그리기 도우미: 모두 문자열을 돌려준다 ──
const A = (o) => Object.entries(o).filter(([, v]) => v !== undefined && v !== null).map(([k, v]) => `${k}="${v}"`).join(' ');
const stroke = (w = LW, c = INK) => ({ stroke: c, 'stroke-width': w, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' });
export const rect = (x, y, w, h, fill = 'none', o = {}) => `<rect ${A({ x, y, width: w, height: h, fill, ...stroke(o.lw ?? LW, o.stroke ?? INK), rx: o.rx })}/>`;
export const circle = (cx, cy, r, fill = 'none', o = {}) => `<circle ${A({ cx, cy, r, fill, ...stroke(o.lw ?? LW, o.stroke ?? INK) })}/>`;
export const ellipse = (cx, cy, rx, ry, fill = 'none', o = {}) => `<ellipse ${A({ cx, cy, rx, ry, fill, ...stroke(o.lw ?? LW, o.stroke ?? INK) })}/>`;
export const line = (x1, y1, x2, y2, o = {}) => `<line ${A({ x1, y1, x2, y2, ...stroke(o.lw ?? LW, o.stroke ?? INK) })}/>`;
export const path = (d, fill = 'none', o = {}) => `<path ${A({ d, fill, ...stroke(o.lw ?? LW, o.stroke ?? INK) })}/>`;
export const poly = (pts, fill = 'none', o = {}) => `<polygon ${A({ points: pts.map((p) => p.join(',')).join(' '), fill, ...stroke(o.lw ?? LW, o.stroke ?? INK) })}/>`;
const nostroke = { stroke: 'none', lw: 0 };

// ── 에셋 목록: { cat, name, w, h, draw() } — draw 는 SVG 조각 문자열 배열 ──
const ASSETS = [
  // props — 거리와 공원의 가구
  { cat: 'props', name: 'bench', w: 76, h: 40, draw: () => [
    rect(-34, -17, 68, 5, P.wood), rect(-34, -32, 68, 5, P.wood), line(-30, -27, -30, -20), line(30, -27, 30, -20),
    line(-28, -12, -28, 0), line(28, -12, 28, 0), line(-31, -20, 31, -20, { lw: FINE }),
  ] },
  { cat: 'props', name: 'lamp', w: 30, h: 96, draw: () => [
    line(0, 0, 0, -78), rect(-9, -6, 18, 6, P.iron), rect(-7, -90, 14, 12, P.yellow, { rx: 3 }), line(-9, -78, 9, -78),
  ] },
  { cat: 'props', name: 'bin', w: 30, h: 36, draw: () => [
    rect(-11, -30, 22, 30, P.iron, { rx: 3 }), rect(-13, -33, 26, 4, P['ink-soft']), line(-4, -24, -4, -8, { lw: FINE, stroke: P.muted }), line(4, -24, 4, -8, { lw: FINE, stroke: P.muted }),
  ] },
  { cat: 'props', name: 'fountain', w: 130, h: 60, draw: () => [
    ellipse(0, -8, 62, 12, P.water), ellipse(0, -8, 64, 14, 'none', { lw: FINE, stroke: P.stone }),
    rect(-6, -42, 12, 34, P.stone), ellipse(0, -44, 20, 5, P.water), line(0, -44, 0, -56), path('M -8 -56 q 8 -6 16 0', 'none', { lw: FINE, stroke: P['water-deep'] }),
  ] },
  { cat: 'props', name: 'stall', w: 110, h: 90, draw: () => [
    poly([[-52, -60], [52, -60], [44, -78], [-44, -78]], P.accent), path('M -52 -60 q 13 6 26 0 q 13 6 26 0 q 13 6 26 0 q 13 6 26 0', 'none', { lw: FINE }),
    line(-46, -60, -46, 0), line(46, -60, 46, 0), rect(-40, -34, 80, 34, P.wood), circle(-20, -40, 5, P.orange), circle(-6, -40, 5, P.yellow), circle(8, -40, 5, P.red), circle(22, -40, 5, P.leaf),
  ] },
  { cat: 'props', name: 'booth', w: 40, h: 90, draw: () => [
    rect(-16, -86, 32, 86, P.paper), rect(-12, -80, 24, 44, P.sky), line(-16, -86, 16, -86), rect(-18, -90, 36, 4, P['accent-deep']), rect(-10, -30, 20, 24, 'none', { lw: FINE }),
  ] },
  { cat: 'props', name: 'garden', w: 96, h: 40, draw: () => [
    rect(-46, -12, 92, 12, P.wood), ...[-36, -22, -8, 6, 20, 34].map((x, i) => line(x, -12, x, -26 - (i % 2) * 4, { lw: FINE, stroke: P['leaf-deep'] })),
    ...[-36, -22, -8, 6, 20, 34].map((x, i) => circle(x, -30 - (i % 2) * 4, 4, [P.red, P.yellow, P.accent, P.orange, P.white, P.yellow][i], nostroke)),
  ] },
  { cat: 'props', name: 'swing', w: 90, h: 100, draw: () => [
    line(-40, 0, -28, -92), line(-16, 0, -28, -92), line(40, 0, 28, -92), line(16, 0, 28, -92), line(-30, -92, 30, -92),
    line(-10, -92, -10, -20, { lw: FINE }), line(10, -92, 10, -20, { lw: FINE }), rect(-14, -20, 28, 4, P.wood),
  ] },
  { cat: 'props', name: 'sign', w: 44, h: 70, draw: () => [ line(0, 0, 0, -44), rect(-20, -66, 40, 24, P.paper, { rx: 2 }), line(-12, -58, 12, -58, { lw: FINE }), line(-12, -50, 6, -50, { lw: FINE }) ] },
  { cat: 'props', name: 'board', w: 70, h: 80, draw: () => [ line(-26, 0, -26, -70), line(26, 0, 26, -70), rect(-32, -76, 64, 40, P.wood), rect(-28, -72, 56, 32, P.paper, { lw: FINE }), rect(-24, -68, 14, 10, P.yellow, nostroke), rect(-6, -66, 18, 8, P.sky, nostroke), rect(10, -60, 10, 12, P.accent, nostroke) ] },
  { cat: 'props', name: 'hydrant', w: 22, h: 34, draw: () => [ rect(-6, -28, 12, 28, P.red, { rx: 3 }), circle(0, -30, 5, P.red), line(-11, -18, 11, -18), circle(-9, -18, 3, P.red), circle(9, -18, 3, P.red) ] },
  { cat: 'props', name: 'mailbox', w: 26, h: 50, draw: () => [ line(0, 0, 0, -30), rect(-11, -46, 22, 18, P.accent, { rx: 6 }), line(-6, -37, 6, -37, { lw: FINE, stroke: P.paper }) ] },
  { cat: 'props', name: 'table', w: 60, h: 34, draw: () => [ rect(-28, -30, 56, 4, P.wood), line(-22, -26, -22, 0), line(22, -26, 22, 0), line(-22, -12, 22, -12, { lw: FINE }) ] },
  { cat: 'props', name: 'chair', w: 26, h: 44, draw: () => [ rect(-10, -22, 20, 3, P.wood), line(-8, -19, -8, 0), line(8, -19, 8, 0), line(-8, -22, -8, -40), line(8, -22, 8, -40), line(-8, -40, 8, -40) ] },
  { cat: 'props', name: 'stage', w: 120, h: 30, draw: () => [ rect(-58, -12, 116, 12, P.wood), line(-58, -12, -50, -20, { lw: FINE }), line(50, -20, 58, -12, { lw: FINE }), rect(-50, -20, 100, 8, P['wood-light']) ] },
  { cat: 'props', name: 'fence', w: 96, h: 36, draw: () => [ ...[-44, -22, 0, 22, 44].map((x) => poly([[x - 4, 0], [x - 4, -26], [x, -32], [x + 4, -26], [x + 4, 0]], P.paper, { lw: FINE })), line(-48, -10, 48, -10, { lw: FINE }), line(-48, -22, 48, -22, { lw: FINE }) ] },
  { cat: 'props', name: 'rock', w: 40, h: 24, draw: () => [ path('M -18 0 q -4 -12 6 -18 q 14 -6 24 4 q 6 8 4 14 z', P.stone), path('M -6 -14 q 6 -2 10 2', 'none', { lw: FINE, stroke: P['stone-deep'] }) ] },
  { cat: 'props', name: 'flowerpot', w: 24, h: 40, draw: () => [ poly([[-10, -16], [10, -16], [8, 0], [-8, 0]], P.brick), rect(-11, -19, 22, 4, P.brick), line(0, -16, 0, -30, { lw: FINE, stroke: P['leaf-deep'] }), circle(0, -33, 5, P.accent, nostroke), circle(-5, -26, 3, P.leaf, nostroke), circle(5, -27, 3, P.leaf, nostroke) ] },
  { cat: 'props', name: 'well', w: 60, h: 80, draw: () => [ rect(-24, -24, 48, 24, P.stone), line(-24, -24, 24, -24), line(-20, -24, -20, -60), line(20, -24, 20, -60), poly([[-28, -60], [28, -60], [0, -78]], P['accent-deep']), line(0, -58, 0, -36, { lw: FINE }), rect(-5, -40, 10, 8, P.wood, { lw: FINE }) ] },
  { cat: 'props', name: 'busstop', w: 90, h: 96, draw: () => [ rect(-40, -90, 80, 6, P.iron), line(-36, -84, -36, 0), line(36, -84, 36, 0), rect(-30, -22, 60, 4, P.wood), line(-28, -18, -28, 0), line(28, -18, 28, 0), rect(-24, -76, 48, 40, P.sky, { lw: FINE }) ] },
  // props — 놀이터(2026-09-28, 백로그 "Playground set"): 미끄럼틀·시소·모래밭·정글짐·스프링라이더·2인용 그네·낮은 담
  { cat: 'props', name: 'slide', w: 100, h: 110, draw: () => [
    rect(-15, -108, 30, 8, P.wood), line(-30, -100, -30, 0), line(-18, -100, -18, 0),
    ...[-84, -64, -44, -24].map((y) => line(-30, y, -18, y, { lw: FINE })),
    path('M 15 -104 Q 56 -70 40 0', P['wood-light']), line(40, 0, 52, 0),
  ] },
  { cat: 'props', name: 'seesaw', w: 116, h: 40, draw: () => [
    poly([[-9, 0], [9, 0], [0, -20]], P.stone), line(-52, -10, 52, -30, { stroke: P.wood }),
    rect(-58, -14, 14, 4, P.wood), rect(44, -34, 14, 4, P.wood),
  ] },
  { cat: 'props', name: 'sandbox', w: 120, h: 30, draw: () => [
    rect(-40, -14, 80, 14, P.wood, { rx: 2 }), ellipse(-2, -14, 38, 6, P.sand),
    poly([[42, -10], [54, -10], [52, 0], [44, 0]], P.red, { lw: FINE }), path('M 44 -10 q 4 -6 8 0', 'none', { lw: FINE }),
  ] },
  { cat: 'props', name: 'climbing-frame', w: 130, h: 90, draw: () => [
    line(-55, 0, -40, -80), line(-25, 0, -40, -80), line(55, 0, 40, -80), line(25, 0, 40, -80), line(-40, -80, 40, -80),
    ...[-24, -8, 8, 24].map((x) => line(x, -80, x, -72, { lw: FINE })),
  ] },
  { cat: 'props', name: 'spring-rider', w: 40, h: 55, draw: () => [
    path('M -3 0 L 3 -8 L -3 -16 L 3 -24 L -3 -32 L 3 -40', 'none', { stroke: P.iron }),
    ellipse(0, -44, 14, 6, P.accent), line(-10, -44, -14, -50, { lw: FINE }), line(10, -44, 14, -50, { lw: FINE }),
  ] },
  { cat: 'props', name: 'swing-double', w: 140, h: 100, draw: () => [
    line(-70, 0, -52, -92), line(-34, 0, -52, -92), line(70, 0, 52, -92), line(34, 0, 52, -92), line(-52, -92, 52, -92),
    line(-36, -92, -36, -20, { lw: FINE }), line(-16, -92, -16, -20, { lw: FINE }), rect(-40, -20, 28, 4, P.wood),
    line(16, -92, 16, -20, { lw: FINE }), line(36, -92, 36, -20, { lw: FINE }), rect(12, -20, 28, 4, P.wood),
  ] },
  { cat: 'props', name: 'low-wall', w: 90, h: 26, draw: () => [ rect(-40, -22, 80, 22, P.stone), rect(-42, -24, 84, 4, P['stone-deep']) ] },
  // flora — 나무·덤불·꽃밭
  { cat: 'flora', name: 'tree-round', w: 90, h: 120, draw: () => [ rect(-5, -46, 10, 46, P.wood), circle(0, -80, 34, P.leaf), circle(-22, -66, 20, P['leaf-deep']), circle(20, -70, 22, P['leaf-deep']), circle(0, -92, 20, P.leaf) ] },
  { cat: 'flora', name: 'tree-tall', w: 70, h: 160, draw: () => [ rect(-4, -60, 8, 60, P.wood), ellipse(0, -110, 28, 46, P['leaf-deep']), ellipse(-8, -122, 16, 28, P.leaf, nostroke) ] },
  { cat: 'flora', name: 'willow', w: 110, h: 140, draw: () => [ rect(-5, -50, 10, 50, P.wood), ellipse(0, -96, 50, 36, P.leaf), ...[-44, -30, -16, 0, 16, 30, 44].map((x, i) => path(`M ${x} -84 q ${i % 2 ? 4 : -4} 24 0 46`, 'none', { lw: FINE, stroke: P['leaf-deep'] })) ] },
  { cat: 'flora', name: 'bush', w: 56, h: 34, draw: () => [ circle(-14, -14, 14, P.leaf), circle(12, -16, 16, P['leaf-deep']), circle(0, -22, 12, P.leaf) ] },
  { cat: 'flora', name: 'hedge', w: 100, h: 40, draw: () => [ rect(-48, -34, 96, 34, P['leaf-deep'], { rx: 8 }), ...[-36, -18, 0, 18, 36].map((x) => circle(x, -34, 8, P.leaf, nostroke)) ] },
  { cat: 'flora', name: 'flowerbed', w: 80, h: 30, draw: () => [ ellipse(0, -4, 38, 8, P.wood), ...[-28, -14, 0, 14, 28].map((x, i) => line(x, -8, x, -18 - (i % 2) * 5, { lw: FINE, stroke: P['leaf-deep'] })), ...[-28, -14, 0, 14, 28].map((x, i) => circle(x, -21 - (i % 2) * 5, 4, [P.accent, P.yellow, P.red, P.white, P.orange][i], nostroke)) ] },
  { cat: 'flora', name: 'sapling', w: 24, h: 50, draw: () => [ line(0, 0, 0, -30), line(0, -30, 0, -44, { lw: FINE, stroke: P['leaf-deep'] }), ellipse(-6, -36, 6, 4, P.leaf, nostroke), ellipse(6, -40, 6, 4, P.leaf, nostroke), rect(-8, -4, 16, 4, P.wood, { lw: FINE }) ] },
  { cat: 'flora', name: 'stump', w: 30, h: 20, draw: () => [ rect(-12, -14, 24, 14, P.wood), ellipse(0, -14, 12, 4, P['wood-light']), ellipse(0, -14, 6, 2, 'none', { lw: FINE, stroke: P.wood }) ] },
  // buildings — 걸어 들어갈 수 있는 정면
  { cat: 'buildings', name: 'house-blue', w: 180, h: 190, draw: () => [ rect(-80, -130, 160, 130, P.sky), poly([[-88, -130], [88, -130], [0, -184]], P['accent-deep']), rect(-16, -56, 32, 56, P['accent-deep']), circle(8, -30, 2, P.yellow, nostroke), rect(-64, -110, 26, 26, P.paper), rect(38, -110, 26, 26, P.paper), line(-51, -110, -51, -84, { lw: FINE }), line(51, -110, 51, -84, { lw: FINE }), rect(40, -180, 12, 30, P.brick) ] },
  { cat: 'buildings', name: 'house-narrow', w: 120, h: 210, draw: () => [ rect(-50, -160, 100, 160, P.paper), poly([[-56, -160], [56, -160], [0, -206]], P.brick), rect(-14, -54, 28, 54, P.wood), rect(-36, -140, 22, 26, P.sky), rect(14, -140, 22, 26, P.sky), rect(-36, -96, 22, 26, P.sky), rect(14, -96, 22, 26, P.sky) ] },
  { cat: 'buildings', name: 'house-corner', w: 220, h: 180, draw: () => [ rect(-100, -120, 200, 120, P['paper-deep']), rect(-108, -126, 216, 8, P['accent-deep']), rect(-100, -176, 90, 50, P['paper-deep']), poly([[-106, -176], [-4, -176], [-55, -200]], P['accent-deep']), rect(-20, -58, 36, 58, P.accent), rect(-80, -104, 30, 30, P.sky), rect(40, -104, 30, 30, P.sky), rect(-80, -166, 22, 22, P.sky) ] },
  { cat: 'buildings', name: 'bakery', w: 200, h: 170, draw: () => [ rect(-90, -120, 180, 120, P.sand), rect(-96, -126, 192, 6, P['accent-deep']), poly([[-96, -126], [96, -126], [96, -140], [-96, -140]], P.accent), path('M -96 -126 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0', 'none', { lw: FINE }), rect(-70, -100, 60, 44, P.paper), rect(20, -100, 50, 44, P.paper), rect(-16, -60, 32, 60, P.wood), circle(-40, -80, 8, P.orange, nostroke), circle(-56, -74, 6, P.yellow, nostroke), rect(-24, -166, 40, 20, P.paper, { rx: 3 }), line(-16, -156, 8, -156, { lw: FINE }) ] },
  { cat: 'buildings', name: 'post-office', w: 200, h: 160, draw: () => [ rect(-90, -120, 180, 120, P.brick), rect(-96, -126, 192, 8, P.stone), ...[-70, -40, 26, 56].map((x) => rect(x, -100, 20, 30, P.paper)), rect(-16, -60, 32, 60, P['accent-deep']), rect(-60, -50, 12, 22, P.accent, { rx: 3 }), rect(-40, -154, 80, 28, P.stone), line(-30, -140, 30, -140, { lw: FINE }) ] },
  { cat: 'buildings', name: 'church', w: 160, h: 250, draw: () => [ rect(-60, -140, 120, 140, P.stone), poly([[-70, -140], [70, -140], [0, -190]], P['accent-deep']), rect(-14, -246, 28, 106, P.stone), poly([[-20, -246], [20, -246], [0, -290]], P['accent-deep']), line(0, -290, 0, -304), line(-6, -298, 6, -298), path('M -12 -60 v -30 a 12 12 0 0 1 24 0 v 30 z', P.wood), path('M -40 -100 v -14 a 8 8 0 0 1 16 0 v 14 z', P.sky), path('M 24 -100 v -14 a 8 8 0 0 1 16 0 v 14 z', P.sky) ] },
  { cat: 'buildings', name: 'clinic', w: 180, h: 150, draw: () => [ rect(-80, -110, 160, 110, P.paper), rect(-86, -116, 172, 8, P.stone), rect(-16, -60, 32, 60, P.sky), rect(-64, -90, 30, 26, P.sky), rect(34, -90, 30, 26, P.sky), rect(-12, -142, 24, 24, P.paper), rect(-4, -138, 8, 16, P.red, nostroke), rect(-8, -134, 16, 8, P.red, nostroke) ] },
  { cat: 'buildings', name: 'cafe', w: 170, h: 150, draw: () => [ rect(-76, -110, 152, 110, P['paper-deep']), poly([[-84, -110], [84, -110], [76, -128], [-76, -128]], P['accent-deep']), path('M -84 -110 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0 q 12 8 24 0', 'none', { lw: FINE }), rect(-60, -92, 44, 50, P.paper), rect(16, -92, 44, 50, P.paper), rect(-14, -56, 28, 56, P.wood), circle(-38, -70, 7, 'none', { lw: FINE }), path('M -34 -70 h 6 a 3 3 0 0 1 0 6 h -4', 'none', { lw: FINE }) ] },
  { cat: 'buildings', name: 'shop-generic', w: 160, h: 140, draw: () => [ rect(-72, -100, 144, 100, P.paper), rect(-78, -106, 156, 10, P.accent), rect(-60, -84, 120, 44, P.sky), rect(-14, -50, 28, 50, P.wood), line(-60, -62, 60, -62, { lw: FINE }) ] },
  // vehicles
  { cat: 'vehicles', name: 'bicycle', w: 64, h: 40, draw: () => [ circle(-20, -12, 12, 'none'), circle(20, -12, 12, 'none'), line(-20, -12, -4, -30), line(-4, -30, 12, -30), line(12, -30, 20, -12), line(-4, -30, 4, -14), line(4, -14, 20, -12), line(-8, -34, 0, -34), line(14, -36, 10, -30) ] },
  { cat: 'vehicles', name: 'cart', w: 70, h: 44, draw: () => [ rect(-28, -30, 50, 20, P.wood), circle(-14, -8, 8, P.iron), circle(12, -8, 8, P.iron), line(22, -26, 36, -22), circle(-8, -34, 5, P.orange, nostroke), circle(4, -35, 5, P.yellow, nostroke), circle(-18, -33, 4, P.red, nostroke) ] },
  { cat: 'vehicles', name: 'bus', w: 200, h: 80, draw: () => [ rect(-94, -66, 188, 54, P.yellow, { rx: 8 }), ...[-80, -50, -20, 10, 40].map((x) => rect(x, -58, 24, 22, P.sky)), rect(70, -58, 18, 42, P.sky), circle(-60, -10, 10, P.iron), circle(60, -10, 10, P.iron), rect(-94, -30, 188, 4, P['accent-deep'], nostroke) ] },
  // animals
  { cat: 'animals', name: 'duck', w: 28, h: 18, draw: () => [ ellipse(0, -6, 9, 5.5, P.sand, { lw: 1.3 }), circle(6, -11, 3.6, P.sand, { lw: 1.3 }), poly([[9, -11], [15, -10], [9, -9]], P.orange, nostroke) ] },
  { cat: 'animals', name: 'squirrel', w: 24, h: 18, draw: () => [ ellipse(0, -4, 5.5, 3.8, P.fur, { lw: 1.3 }), circle(4.5, -7, 2.6, P.fur, { lw: 1.3 }), ellipse(-7, -6, 5, 3, P.fur, { lw: 1.3 }) ] },
  { cat: 'animals', name: 'dog', w: 40, h: 26, draw: () => [ ellipse(0, -10, 13, 7, P['fur-light'], { lw: 1.3 }), circle(13, -16, 5, P['fur-light'], { lw: 1.3 }), line(-7, -4, -8, 0, { lw: 1.3 }), line(6, -4, 7, 0, { lw: 1.3 }), path('M -12 -12 q -6 -8 -2 -12', 'none', { lw: 1.3 }), ellipse(15, -20, 2.5, 4, P.fur, nostroke) ] },
  { cat: 'animals', name: 'cat', w: 30, h: 22, draw: () => [ ellipse(0, -8, 10, 6, P.iron, { lw: 1.3 }), circle(10, -13, 4.5, P.iron, { lw: 1.3 }), poly([[7, -16], [8, -20], [10, -16]], P.iron, nostroke), poly([[11, -16], [13, -20], [14, -16]], P.iron, nostroke), path('M -10 -8 q -8 -2 -6 -12', 'none', { lw: 1.3 }) ] },
  // sky
  { cat: 'sky', name: 'cloud-1', w: 120, h: 44, draw: () => [ path('M -50 -6 a 14 14 0 0 1 20 -18 a 18 18 0 0 1 34 -6 a 14 14 0 0 1 26 10 a 10 10 0 0 1 12 14 z', P.white, { lw: FINE, stroke: P.stone }) ] },
  { cat: 'sky', name: 'cloud-2', w: 90, h: 34, draw: () => [ path('M -40 -4 a 12 12 0 0 1 18 -14 a 14 14 0 0 1 26 -4 a 12 12 0 0 1 22 8 a 8 8 0 0 1 6 10 z', P.white, { lw: FINE, stroke: P.stone }) ] },
  { cat: 'sky', name: 'sun', w: 60, h: 60, draw: () => [ circle(0, -30, 16, P.yellow, { lw: FINE, stroke: P.orange }), ...[0, 45, 90, 135, 180, 225, 270, 315].map((a) => { const r = (a * Math.PI) / 180; return line(Math.cos(r) * 20, -30 + Math.sin(r) * 20, Math.cos(r) * 27, -30 + Math.sin(r) * 27, { lw: FINE, stroke: P.orange }); }) ] },
  // ground — 3D 마을(town3d)의 바닥 타일. tile: true → 원점이 왼쪽 위(viewBox 0 0 w h), 이어 붙여도 이음새가 안 보이게 가장자리를 맞춘다
  { cat: 'ground', name: 'grass', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P.leaf, nostroke),
    ...[[12, 20], [40, 8], [70, 30], [100, 14], [24, 60], [58, 72], [92, 58], [116, 90], [10, 104], [46, 112], [80, 100], [30, 88]].map(([x, y]) => path(`M ${x} ${y} l 2 -7 l 2 7 M ${x + 4} ${y} l 2 -5 l 2 5`, 'none', { lw: 1.2, stroke: P['leaf-deep'] })),
    ...[[64, 44], [20, 40], [104, 76]].map(([x, y]) => ellipse(x, y, 9, 4, P['leaf-deep'], nostroke)),
  ] },
  { cat: 'ground', name: 'cobble', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P['stone-deep'], nostroke),
    ...Array.from({ length: 8 }, (_, r) => Array.from({ length: 4 }, (_, c) => rect(c * 32 + (r % 2 ? 16 : 0) - (r % 2 ? 16 : 0), r * 16, 30, 14, r % 3 === 0 ? P.stone : P['paper-deep'], { rx: 4, lw: 1.2, stroke: P.muted }))).flat(),
  ] },
  { cat: 'ground', name: 'dirt', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P.straw, nostroke), ...[[20, 30], [70, 20], [100, 70], [40, 90], [90, 110]].map(([x, y]) => ellipse(x, y, 10, 5, P.sand, nostroke)), ...[[56, 56], [14, 100]].map(([x, y]) => circle(x, y, 2.5, P.wood, nostroke)),
  ] },
  // faces — 상자 건물의 벽면·지붕 텍스처(1 unit = 1cm 쯤; 3D 에서 늘려 붙인다). faceSet 이 색만 바꿔 세 벌을 만든다
  ...['sky', 'sand', 'paper', 'brick'].flatMap((wall) => [
    { cat: 'faces', name: `wall-front-${wall}`, w: 200, h: 140, tile: true, draw: () => [
      rect(0, 0, 200, 140, P[wall], nostroke), rect(0, 0, 200, 8, P['paper-deep'], nostroke),
      rect(28, 34, 40, 44, P.paper), rect(132, 34, 40, 44, P.paper), line(48, 34, 48, 78, { lw: FINE }), line(152, 34, 152, 78, { lw: FINE }), line(28, 56, 68, 56, { lw: FINE }), line(132, 56, 172, 56, { lw: FINE }),
      rect(24, 78, 48, 5, P['stone-deep'], nostroke), rect(128, 78, 48, 5, P['stone-deep'], nostroke),
      rect(82, 70, 36, 70, wall === 'brick' ? P.wood : P['accent-deep']), rect(88, 78, 24, 26, 'none', { lw: FINE }), rect(88, 108, 24, 26, 'none', { lw: FINE }), circle(110, 106, 2.2, P.yellow, nostroke),
      rect(74, 134, 52, 6, P.stone, nostroke), rect(0, 130, 200, 10, P['stone-deep'], nostroke),
    ] },
    { cat: 'faces', name: `wall-side-${wall}`, w: 140, h: 140, tile: true, draw: () => [
      rect(0, 0, 140, 140, P[wall], nostroke), rect(0, 0, 140, 8, P['paper-deep'], nostroke), rect(50, 40, 40, 44, P.paper), line(70, 40, 70, 84, { lw: FINE }), line(50, 62, 90, 62, { lw: FINE }), rect(46, 84, 48, 5, P['stone-deep'], nostroke), rect(0, 130, 140, 10, P['stone-deep'], nostroke),
    ] },
  ]),
  ...['accent-deep', 'brick', 'iron', 'wood'].map((roof) => ({ cat: 'faces', name: `roof-${roof}`, w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P[roof], nostroke),
    ...Array.from({ length: 8 }, (_, r) => Array.from({ length: 4 }, (_, c) => path(`M ${c * 32 + (r % 2 ? 16 : 0)} ${r * 16 + 14} a 16 12 0 0 1 32 0`, 'none', { lw: 1.4, stroke: P['ink-soft'] }))).flat(),
  ] })),
  // 벽 재질 타일(진짜 집처럼, 2026-09-28): 널빤지·벽돌·회벽 — 상자 벽에 triplanar 로 붙는다
  { cat: 'faces', name: 'wall-plank', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P['wood-light'], nostroke),
    ...Array.from({ length: 8 }, (_, r) => [line(0, r * 16 + 15, 128, r * 16 + 15, { lw: 1.4, stroke: P.wood }), line((r * 37) % 128, r * 16 + 2, (r * 37) % 128, r * 16 + 14, { lw: 1.2, stroke: P.wood })]).flat(),
  ] },
  { cat: 'faces', name: 'wall-brick', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P['stone-deep'], nostroke),
    ...Array.from({ length: 8 }, (_, r) => Array.from({ length: 4 }, (_, c) => rect(c * 32 + (r % 2 ? 16 : 0) - (r % 2 ? 16 : 0), r * 16 + 1, 30, 13, (r + c) % 5 === 0 ? P['stone'] : P.brick, { rx: 1, lw: 1.1, stroke: P['stone-deep'] }))).flat(),
  ] },
  { cat: 'faces', name: 'wall-stucco', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P['paper-deep'], nostroke), ...[[14, 20], [60, 12], [104, 40], [30, 70], [80, 84], [118, 110], [8, 118], [50, 100]].map(([x, y]) => circle(x, y, 2.2, P.stone, nostroke)),
  ] },
  { cat: 'faces', name: 'roof-shingle', w: 128, h: 128, tile: true, draw: () => [
    rect(0, 0, 128, 128, P['ink-soft'], nostroke),
    ...Array.from({ length: 8 }, (_, r) => Array.from({ length: 4 }, (_, c) => rect(c * 32 + (r % 2 ? 16 : 0) - (r % 2 ? 16 : 0), r * 16, 31, 15, (r + c) % 3 ? P.muted : P.line, { rx: 2, lw: 1.1, stroke: P['ink-soft'] }))).flat(),
  ] },
  { cat: 'faces', name: 'chibi-face', w: 64, h: 64, tile: true, draw: () => [ rect(0, 0, 64, 64, P.sand, nostroke), circle(22, 30, 3.5, P.ink, nostroke), circle(42, 30, 3.5, P.ink, nostroke), path('M 26 44 q 6 4 12 0', 'none', { lw: 1.6 }) ] },
  // figures — 3D 디오라마용 정지 자세(2D 무대에서는 figure.gd 가 그린다; 여기선 같은 관절 좌표를 한 장으로)
  { cat: 'figures', name: 'stand', w: 24, h: 50, draw: () => [
    line(0, -16, 0, -34), line(0, -16, -4, -8), line(-4, -8, -5, 0), line(0, -16, 4, -8), line(4, -8, 5, 0),
    line(0, -34, -5, -26), line(-5, -26, -6, -18), line(0, -34, 5, -26), line(5, -26, 6, -18), circle(0, -42, 7, P.ink, { stroke: P.ink }),
  ] },
  { cat: 'figures', name: 'run', w: 40, h: 50, draw: () => [
    line(0, -18, 6, -35), line(0, -18, 9, -12), line(9, -12, 12, -2), line(0, -18, -8, -10), line(-8, -10, -14, -4),
    line(6, -35, 14, -30), line(14, -30, 16, -22), line(6, -35, -2, -28), line(-2, -28, -6, -34), circle(8, -43, 7, P.ink, { stroke: P.ink }),
  ] },
  // items — 손에 드는 것(16~28px)
  { cat: 'items', name: 'hat', w: 24, h: 12, draw: () => [ rect(-12, -3, 24, 3, P.ink, nostroke), rect(-7, -12, 14, 9, P.ink, { rx: 2, ...nostroke }) ] },
  { cat: 'items', name: 'cup', w: 14, h: 16, draw: () => [ rect(-5, -14, 10, 14, P.paper, { lw: FINE }), path('M 5 -11 h 3 a 3 3 0 0 1 0 6 h -3', 'none', { lw: FINE }) ] },
  { cat: 'items', name: 'broom', w: 14, h: 40, draw: () => [ line(0, -40, 0, -10, { lw: FINE, stroke: P.wood }), poly([[-6, -10], [6, -10], [8, 0], [-8, 0]], P.straw, { lw: FINE }) ] },
  { cat: 'items', name: 'umbrella', w: 30, h: 34, draw: () => [ path('M -14 -18 a 14 14 0 0 1 28 0 z', P.accent, { lw: FINE }), line(0, -18, 0, -2, { lw: FINE }), path('M 0 -2 a 3 3 0 0 0 6 0', 'none', { lw: FINE }) ] },
  { cat: 'items', name: 'apple', w: 12, h: 14, draw: () => [ circle(0, -6, 5.5, P.red, { lw: FINE }), line(0, -11, 1, -14, { lw: FINE, stroke: P.wood }) ] },
  { cat: 'items', name: 'newspaper', w: 18, h: 14, draw: () => [ rect(-9, -13, 18, 13, P.paper, { lw: FINE }), line(-6, -9, 6, -9, { lw: 1.2 }), line(-6, -5, 3, -5, { lw: 1.2 }) ] },
  { cat: 'items', name: 'basket', w: 22, h: 18, draw: () => [ poly([[-10, -12], [10, -12], [8, 0], [-8, 0]], P.straw, { lw: FINE }), path('M -6 -12 a 6 6 0 0 1 12 0', 'none', { lw: FINE }) ] },
  { cat: 'items', name: 'wrench', w: 10, h: 24, draw: () => [ line(0, -20, 0, -2, { lw: 2, stroke: P.iron }), circle(0, -21, 3.5, 'none', { lw: 2, stroke: P.iron }) ] },
];

// ── 쓰기 ──
const svg = (a) => {
  const body = a.draw().join('\n  ');
  const vb = a.tile ? `0 0 ${a.w} ${a.h}` : `${-a.w / 2} ${-a.h} ${a.w} ${a.h}`; // 타일·벽면은 왼쪽 위 원점, 서 있는 것은 발끝 원점
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" width="${a.w}" height="${a.h}">\n  <!-- ${a.cat}/${a.name} — generated by game/tools/assets.mjs; edit the generator, not this file -->\n  ${body}\n</svg>\n`;
};
const manifest = [];
for (const a of ASSETS) {
  const dir = join(ROOT, 'svg', a.cat); mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${a.name}.svg`), svg(a));
  manifest.push({ id: `${a.cat}/${a.name}`, cat: a.cat, name: a.name, w: a.w, h: a.h, ...(a.tile ? { tile: true } : {}) });
}
writeFileSync(join(ROOT, 'manifest.json'), JSON.stringify({ _: 'generated by game/tools/assets.mjs — origin is the foot point, 1 unit = 1px at depth 1', assets: manifest }, null, 1) + '\n');
console.log(`assets: wrote ${manifest.length} svg files + manifest.json`);
