// Build the original Documents layout using final deliverables only.
import { readFile, writeFile, mkdir, copyFile, stat } from 'node:fs/promises';
import { dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
const dir = dirname(fileURLToPath(import.meta.url));
const root = resolve(dir, '../..');
const stage = resolve(dir, '.library-stage');
const files = [], paths = new Map();
const add = async (source, target, guidePath) => {
  assert((target.startsWith('brand/') || target.startsWith('video/')) && !target.includes('..'));
  const destination = resolve(stage, target);
  await mkdir(dirname(destination), { recursive: true });
  await copyFile(resolve(root, source), destination);
  files.push(target);
  if (guidePath) paths.set(guidePath, relative(resolve(stage, 'brand'), destination).replaceAll('\\', '/'));
};
const write = async (target, text) => {
  await mkdir(dirname(resolve(stage, target)), { recursive: true });
  await writeFile(resolve(stage, target), text);
  files.push(target);
};
for (const name of ['pz-logo-icon-512.png', 'pz-logo-1200sq.png', 'pz-logo-1200sq-dark.png', 'pz-logo-4x1-1200x300.png', 'pz-logo-4x1-1200x300-dark.png']) {
  await add(`brand/poz/distribution/logo/original/${name}`, `brand/logo/original/${name}`);
}
for (const style of ['badge', 'compact', 'stacked']) for (const mode of ['light', 'dark']) {
  const name = `pz-logo-${style}-${mode}.png`;
  await add(`brand/poz/distribution/logo/variants/${name}`, `brand/logo/variants/${name}`);
}
await add('brand/poz/wordmark.svg', 'brand/logo/original/wordmark.svg', 'wordmark.svg');
for (const name of ['poz-wordmark-light.svg', 'poz-wordmark.png', 'poz-wordmark-light.png']) await add(`site/public/brand/${name}`, `brand/logo/original/${name}`);
for (const name of ['app-icon.png', 'app-icon-mauve.png']) await add(`brand/poz/${name}`, `brand/logo/original/${name}`, name);
await add('brand/poz/preview.png', 'brand/logo/preview.png', 'preview.png');
for (const name of ['og.png', 'og-square.png', 'og-vertical.png']) await add(`site/public/${name}`, `brand/${name}`);
for (const name of ['face.svg', 'favicon.ico', 'preview.png', ...[16,32,48,64,180,256,512].map(size => `face-${size}.png`)]) {
  await add(`brand/poz/favicon/${name}`, `brand/logo/favicon/${name}`, `favicon/${name}`);
}
const poses = { iris: 'welcome', bracket: 'thinking', cache: 'receipt', null: 'sleeping' };
for (const [name, pose] of Object.entries(poses)) {
  const folder = name[0].toUpperCase() + name.slice(1);
  for (const file of [`${name}.png`, `${name}-${pose}.png`]) await add(`brand/poz/characters/${file}`, `brand/characters/${folder}/${file}`, `characters/${file}`);
  for (const ext of ['mp4', 'gif']) {
    const file = `${name}-loop.${ext}`;
    await add(`brand/poz/characters/motion/${file}`, `brand/characters/${folder}/animations/${file}`, `characters/motion/${file}`);
  }
}
await add('brand/poz/characters/lineup.png', 'brand/characters/group/lineup.png', 'characters/lineup.png');
for (const name of ['poz-locals-wide.mp4', 'poz-locals-vertical.mp4']) await add(`brand/poz/characters/motion/${name}`, `video/${name}`, `characters/motion/${name}`);
await add('brand/poz/characters/motion/README.md', 'video/README.md', 'characters/MOTION_PROMPTS.md');
await add('brand/poz/BRAND_GUIDE.md', 'brand/BRAND_GUIDE.md', 'BRAND_GUIDE.md');
let cast = await readFile(resolve(dir, 'characters/CAST.md'), 'utf8');
for (const [oldPath, newPath] of paths) if (oldPath.startsWith('characters/')) cast = cast.replaceAll('`' + oldPath.slice(11) + '`', '`' + newPath.slice(11) + '`');
cast = cast.replace('`motion/`: four 4-second cutout loops (MP4/GIF) and two 16-second introduction montages.', 'Each character folder contains its 4-second cutout loop in `animations/` (MP4/GIF). The two 16-second introduction montages are in `../../video/`.');
await write('brand/characters/CAST.md', cast);
paths.set('characters/CAST.md', 'characters/CAST.md');
let guide = await readFile(resolve(dir, 'index.html'), 'utf8');
guide = guide.replace(/\b(src|href|poster)="([^"]+)"/g, (match, attribute, path) => {
  assert(paths.has(path), `Unmapped guide reference: ${path}`);
  return `${attribute}="${paths.get(path)}"`;
}).replace('제작 프롬프트', '모션 사용 안내');
await write('brand/index.html', guide);
let gallery = await readFile(resolve(dir, 'characters/qa.html'), 'utf8');
gallery = gallery.replace(/\b(src|href)="([^"]+)"/g, (match, attribute, path) => {
  if (path === '../index.html') return match;
  const mapped = paths.get(`characters/${path}`);
  assert(mapped, `Unmapped character reference: ${path}`);
  return `${attribute}="${mapped.slice('characters/'.length)}"`;
});
await write('brand/characters/index.html', gallery);
for (const path of ['brand/index.html', 'brand/characters/index.html']) {
  const html = await readFile(resolve(stage, path), 'utf8');
  for (const match of html.matchAll(/\b(?:src|href|poster)="([^"]+)"/g)) {
    const asset = resolve(dirname(resolve(stage, path)), match[1]);
    assert(files.includes(relative(stage, asset).replaceAll('\\', '/')), `Undelivered link: ${match[1]}`);
    assert((await stat(asset)).isFile());
  }
}
// Exact obsolete paths inspected for this user-requested cleanup, never wildcards.
const obsolete = [
  'brand/legacy-before-poz-20260911-163137', 'brand/legacy-before-poz-20260911-163354',
  'brand/legacy-before-poz-complete-20260911-171236', 'brand/legacy-before-poz-complete-20260911-171724', 'brand/legacy-before-poz-complete-20260911-172731',
  'brand/characters/legacy-before-poz-20260911-165044',
  'brand/poz-current', 'brand/logo/poz-current', 'brand/characters/poz-current', 'brand/logo/poz-concept-v1.png',
  ...['pz-cast-lineup.png', 'pz-characters-1200sq.png', 'pz-characters-1200x628.png', 'pz-characters-original.png', 'pz-characters-transparent.png'].map(name => `brand/characters/group/${name}`),
  ...['pz-core-cast-animation-horizontal-15s.mp4', 'pz-core-cast-animation-vertical-15s.mp4', 'pz-shorts.mp4', 'pz-square-community.mp4', 'pz-square-notachatbot.mp4', 'pz-vert-community.mp4', 'pz-vert-notachatbot.mp4', 'pz-wide-community.mp4', 'pz-wide-notachatbot.mp4'].map(name => `video/${name}`),
];
for (const name of Object.keys(poses)) {
  const folder = `brand/characters/${name[0].toUpperCase() + name.slice(1)}`;
  obsolete.push(`${folder}/${name}-motion-sheet-v1.png`, `${folder}/${name}-motion-sheet-v2-clean.png`);
  for (const style of ['clean', 'fluid']) for (const ext of ['gif', 'mp4']) obsolete.push(`${folder}/animations/${name}-${style}-loop-4s.${ext}`);
}
assert.equal(new Set(files).size, files.length);
for (const oldPath of obsolete) for (const target of files) assert(target !== oldPath && !target.startsWith(oldPath + '/'));
await writeFile(resolve(stage, 'manifest.json'), JSON.stringify({ files, obsolete }, null, 2));
console.log(`Prepared ${files.length} final files in the original Documents layout. All gallery links resolve. ${obsolete.length} explicit obsolete paths listed for optional recycling.`);
