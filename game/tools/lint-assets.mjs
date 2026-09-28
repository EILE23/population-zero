// 에셋 린트 — assets/svg/**.svg 가 규칙(assets/README.md)을 지키는지. CI 의 Godot 게이트가 먼저 돌린다; 하나라도 어기면 그 실행은 버려진다.
//  - viewBox 는 "-w/2 -h w h" (원점 = 발끝), width/height 와 일치
//  - 색은 palette.json 의 것만(대소문자 무시), 'none' 허용
//  - 금지: <text> <image> <filter> <script> <style> <foreignObject>, url(), 그라디언트
//  - 크기: props/flora/items ≤ 260×260, buildings ≤ 420×320, 나머지 ≤ 260×120 (sky 제외)
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets');
const palette = new Set(Object.entries(JSON.parse(readFileSync(join(ROOT, 'palette.json'), 'utf8'))).filter(([k]) => k !== '_').map(([, v]) => String(v).toLowerCase()));
const LIMITS = { buildings: [420, 320], sky: [400, 200], ground: [256, 256], faces: [256, 256], default: [260, 260] };
const TILED = new Set(['ground', 'faces']); // 타일·벽면 — 원점이 왼쪽 위(viewBox 0 0 w h); 3D 상자에 늘려 붙인다

function* walk(dir) { for (const e of readdirSync(dir)) { const p = join(dir, e); if (statSync(p).isDirectory()) yield* walk(p); else if (p.endsWith('.svg')) yield p; } }

let files = 0, bad = 0;
for (const file of walk(join(ROOT, 'svg'))) {
  files++;
  const rel = relative(ROOT, file).replace(/\\/g, '/');
  const cat = rel.split('/')[1];
  const s = readFileSync(file, 'utf8');
  const errs = [];
  const vb = s.match(/viewBox="([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+)"/);
  const w = Number(s.match(/\swidth="([\d.]+)"/)?.[1]), h = Number(s.match(/\sheight="([\d.]+)"/)?.[1]);
  if (!vb) errs.push('no viewBox');
  else {
    const [x, y, vw, vh] = vb.slice(1).map(Number);
    if (TILED.has(cat)) { if (x !== 0 || y !== 0) errs.push(`tiles/faces start at the top-left: viewBox should be "0 0 ${vw} ${vh}"`); }
    else if (Math.abs(x + vw / 2) > 0.01 || Math.abs(y + vh) > 0.01) errs.push(`origin must be the foot point: viewBox should be "${-vw / 2} ${-vh} ${vw} ${vh}"`);
    if (vw !== w || vh !== h) errs.push('width/height must equal the viewBox size');
    const [mw, mh] = LIMITS[cat] ?? LIMITS.default;
    if (vw > mw || vh > mh) errs.push(`too big for ${cat}: ${vw}×${vh} > ${mw}×${mh}`);
  }
  for (const tag of ['text', 'image', 'filter', 'script', 'style', 'foreignObject', 'linearGradient', 'radialGradient']) if (new RegExp(`<${tag}[\\s>]`).test(s)) errs.push(`forbidden <${tag}>`);
  if (/url\(/.test(s)) errs.push('forbidden url()');
  for (const m of s.matchAll(/#[0-9a-fA-F]{3,8}\b/g)) { const c = m[0].toLowerCase(); if (!palette.has(c)) errs.push(`colour ${c} is not in palette.json`); }
  for (const m of s.matchAll(/(?:fill|stroke)="([a-zA-Z]+)"/g)) if (!['none', 'currentColor'].includes(m[1])) errs.push(`named colour "${m[1]}" — use the palette`);
  if (errs.length) { bad++; console.error(`✗ ${rel}\n    ${[...new Set(errs)].join('\n    ')}`); }
}
if (!files) { console.error('assets: no svg files found'); process.exit(1); }
console.log(`assets: ${files} files, ${bad} with problems`);
process.exit(bad ? 1 : 0);
