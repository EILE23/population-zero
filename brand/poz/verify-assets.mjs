// Read-only verification of deliverable integrity and browser/native references.
import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const sharp = require(process.argv[2] || 'sharp');
const dir = dirname(fileURLToPath(import.meta.url));
const root = resolve(dir, '../..');
const names = ['iris', 'bracket', 'cache', 'null', 'iris-welcome', 'bracket-thinking', 'cache-receipt', 'null-sleeping'];
const hash = async path => createHash('sha256').update(await readFile(path)).digest('hex');
const verifyTransparentFace = async (input, size) => {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  assert.equal(info.width, size); assert.equal(info.height, size);
  let painted = 0;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const alpha = data[(y * size + x) * 4 + 3];
    painted += alpha / 255;
    // Corners alone would miss the rejected rounded-square background.
    if (x === 0 || y === 0 || x === size - 1 || y === size - 1) assert.equal(alpha, 0, `${size}px outer edge at ${x},${y}`);
  }
  const coverage = painted / (size * size);
  assert(coverage > 0.40 && coverage < 0.66, `${size}px silhouette coverage: ${coverage}`);
  assert.equal(data[(Math.floor(size * 0.45) * size + Math.floor(size * 0.35)) * 4 + 3], 255, 'Eye is opaque, not a hole');
};
for (const name of names) {
  const source = resolve(dir, `characters/${name}.png`);
  const meta = await sharp(source).metadata(), stats = await sharp(source).stats();
  assert.equal(meta.hasAlpha, true, name); assert.equal(stats.channels[3].min, 0, name); assert.equal(stats.channels[3].max, 255, name);
  for (const folder of ['site/public/brand/characters', 'app/assets/characters']) assert.equal(await hash(resolve(root, `${folder}/${name}.png`)), await hash(source), name);
}
const ico = await readFile(resolve(dir, 'favicon/favicon.ico'));
assert.equal(ico.readUInt16LE(2), 1); assert.equal(ico.readUInt16LE(4), 3);
for (const [i, size] of [16, 32, 48].entries()) {
  const p = 6 + i * 16; assert.equal(ico[p], size); assert.equal(ico[p + 1], size);
  const image = ico.subarray(ico.readUInt32LE(p + 12), ico.readUInt32LE(p + 12) + ico.readUInt32LE(p + 8));
  assert.equal((await sharp(image).metadata()).width, size);
  await verifyTransparentFace(image, size);
}
assert.equal(await hash(resolve(root, 'site/src/app/icon.svg')), await hash(resolve(dir, 'favicon/face.svg')));
assert.equal(await hash(resolve(root, 'site/src/app/favicon.ico')), await hash(resolve(dir, 'favicon/favicon.ico')));
assert.equal(await hash(resolve(root, 'app/assets/favicon.png')), await hash(resolve(dir, 'favicon/face-64.png')));
for (const size of [16, 32, 48, 64, 180, 256, 512]) {
  const source = resolve(dir, `favicon/face-${size}.png`);
  await verifyTransparentFace(source, size);
  if (size <= 64) assert.equal(await hash(resolve(root, `site/public/brand/favicon-${size}.png`)), await hash(source));
}
const apple = await sharp(resolve(root, 'site/src/app/apple-icon.png')).metadata();
assert.equal(apple.width, 180); assert.equal(apple.hasAlpha, false);
const html = await readFile(resolve(dir, 'index.html'), 'utf8');
for (const match of html.matchAll(/(?:src|href)="([^"]+)"/g)) assert.equal((await stat(resolve(dir, match[1]))).isFile(), true, match[1]);
const native = await readFile(resolve(root, 'app/src/ui/Character.tsx'), 'utf8');
for (const name of names) assert(native.includes(`${name}.png`), `Native pose missing: ${name}`);
for (const name of names.slice(0, 4)) {
  const meta = await sharp(resolve(dir, `characters/motion/${name}-loop.gif`), { animated: true }).metadata();
  assert.equal(meta.pages, 48, `${name} GIF frames`);
  assert.equal(meta.width, 400, `${name} GIF width`);
}
console.log('PASS: 8 alpha PNGs; exact web/native copies; face SVG and transparent PNG/ICO/Expo edges + silhouette; separate Apple icon; guide links; 8 bundled pose references; 4 animated GIFs.');
