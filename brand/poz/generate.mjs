// Render every POZ asset from one outlined SVG. No font or image-generation dependency.
// node brand/poz/generate.mjs [absolute path to a sharp installation]
import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const sharp = require(process.argv[2] || 'sharp');
const dir = dirname(fileURLToPath(import.meta.url));
const root = resolve(dir, '../..');
const tokens = await readFile(resolve(root, 'site/src/design/tokens.css'), 'utf8');
const color = (name) => {
  const value = tokens.match(new RegExp(`--${name}:\\s*(#[0-9a-fA-F]{6})`))?.[1];
  if (!value) throw new Error(`Missing design token ${name}`);
  return value;
};
const ink = color('ink-800'), mauve = color('accent'), paper = color('paper');
const source = await readFile(resolve(dir, 'wordmark.svg'), 'utf8');
const paths = source.match(/<path\b[^>]*\/>/g).join('\n');
const svg = (w, h, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const mark = (x, y, w, fill = ink) => `<g fill="${fill}" transform="translate(${x} ${y}) scale(${w / 780})">${paths}</g>`;
const rect = (w, h, fill, radius = 0) => `<rect width="${w}" height="${h}" rx="${radius}" fill="${fill}"/>`;
const label = (x, y, text, size = 24, fill = ink) => `<text x="${x}" y="${y}" fill="${fill}" font-family="Arial, sans-serif" font-size="${size}" letter-spacing="2">${text}</text>`;
const write = async (relative, data) => {
  const target = resolve(root, relative);
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, data);
};
const png = async (relative, image, size) => {
  let pipeline = sharp(Buffer.from(image));
  if (size) pipeline = pipeline.resize(size, size);
  // A full-bleed background must have no alpha channel (required for iOS launcher icons).
  if (/<svg[^>]*><rect [^>]*rx="0"[^>]*\/>/.test(image)) pipeline = pipeline.removeAlpha();
  await write(relative, await pipeline.png().toBuffer());
};
const icon = (bg, fg, width = 768, rounded = false) => svg(1024, 1024,
  (bg ? rect(1024, 1024, bg, rounded ? 220 : 0) : '') + mark((1024 - width) / 2, (1024 - width * 310 / 780) / 2, width, fg));
const webMark = (fill) => svg(780, 310, mark(0, 0, 780, fill));
const lockup = (dark = false) => svg(1200, 300,
  mark(20, 60, 450, dark ? paper : ink) + label(550, 158, 'population.town', 38, dark ? mauve : ink));
const social = (w, h) => svg(w, h, rect(w, h, paper) +
  mark(w * .10, h * .20, w * .80) +
  label(w * .10, h * .79, 'Trends. Stories. Conversation.', w * .027) +
  `<circle cx="${w * .108}" cy="${h * .9}" r="${w * .008}" fill="${mauve}"/>` +
  label(w * .135, h * .91, 'population.town', w * .021));

await write('site/public/brand/poz-wordmark.svg', webMark(ink));
await write('site/public/brand/poz-wordmark-light.svg', webMark(paper));
await write('site/public/brand/poz-lockup.svg', lockup());
await write('site/public/brand/poz-lockup-dark.svg', lockup(true));
await write('site/src/app/icon.svg', icon(ink, paper, 850, true));
await png('site/src/app/apple-icon.png', icon(ink, paper), 180);
await png('site/public/brand/poz-icon.png', icon(ink, paper));
await png('site/public/brand/poz-icon-mauve.png', icon(mauve, ink));
await png('site/public/brand/poz-wordmark.png', webMark(ink));
await png('site/public/brand/poz-wordmark-light.png', webMark(paper));
await png('site/public/brand/poz-lockup.png', lockup());
await png('site/public/brand/poz-lockup-dark.png', lockup(true));
for (const [name, w, h] of [['og', 1200, 630], ['og-square', 1200, 1200], ['og-vertical', 1080, 1920]]) {
  await png(`site/public/${name}.png`, social(w, h));
}

// Native launcher images are full-bleed squares; the operating system supplies the mask.
await png('app/assets/icon.png', icon(ink, paper));
await png('app/assets/poz-logo.png', webMark(ink));
await png('app/assets/poz-logo-light.png', webMark(paper));
await png('app/assets/splash-icon.png', icon(null, ink, 640));
await png('app/assets/favicon.png', icon(ink, paper, 850, true), 64);
// Adaptive foreground stays inside the central 66/108 safe circle, including its corners.
await png('app/assets/android-icon-foreground.png', icon(null, paper, 560));
await png('app/assets/android-icon-monochrome.png', icon(null, '#FFFFFF', 560));
await png('app/assets/android-icon-background.png', svg(1024, 1024, rect(1024, 1024, ink)));

// ICO supports PNG-compressed entries. Keep 16/32/48px explicit for browser compatibility.
const sizes = [16, 32, 48];
const images = await Promise.all(sizes.map((n) => sharp(Buffer.from(icon(ink, paper, 850, true))).resize(n, n).png().toBuffer()));
const header = Buffer.alloc(6 + 16 * sizes.length);
header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
let offset = header.length;
images.forEach((image, i) => {
  const p = 6 + i * 16;
  header[p] = sizes[i]; header[p + 1] = sizes[i];
  header.writeUInt16LE(1, p + 4); header.writeUInt16LE(32, p + 6);
  header.writeUInt32LE(image.length, p + 8); header.writeUInt32LE(offset, p + 12);
  offset += image.length;
});
await write('site/src/app/favicon.ico', Buffer.concat([header, ...images]));

const proof = svg(1440, 960, rect(1440, 960, '#F5F5F7') +
  label(72, 66, 'POZ / BRAND ASSETS', 16) + mark(330, 115, 780) +
  label(535, 475, 'population.town', 24) +
  `<g transform="translate(72 570)">${rect(260, 260, ink, 55)}${mark(32, 91, 196, paper)}</g>` +
  `<g transform="translate(385 570)">${rect(260, 260, mauve, 55)}${mark(32, 91, 196, ink)}</g>` +
  `<g transform="translate(710 600)">${rect(650, 210, ink, 24)}${mark(30, 57, 240, paper)}${label(310, 114, 'population.town', 22, mauve)}</g>` +
  label(72, 880, 'APP / DARK', 15) + label(385, 880, 'APP / MAUVE', 15) + label(710, 880, 'WEB', 15));
await write('brand/poz/preview.svg', proof);
await png('brand/poz/preview.png', proof);
await copyFile(resolve(root, 'app/assets/icon.png'), resolve(dir, 'app-icon.png'));
await copyFile(resolve(root, 'site/public/brand/poz-icon-mauve.png'), resolve(dir, 'app-icon-mauve.png'));

// Compatibility exports for the existing Documents/aproject brand library.
// Kept separate so syncing the library is an explicit, reviewable operation.
const exports = 'brand/poz/distribution';
for (const [name, w, h] of [['og', 1200, 630], ['og-square', 1200, 1200], ['og-vertical', 1080, 1920]]) {
  await png(`${exports}/${name}.png`, social(w, h));
}
await png(`${exports}/logo/original/pz-logo-icon-512.png`, icon(ink, paper), 512);
for (const dark of [false, true]) {
  const bg = dark ? ink : paper, fg = dark ? paper : ink;
  const suffix = dark ? '-dark' : '';
  await png(`${exports}/logo/original/pz-logo-1200sq${suffix}.png`, icon(bg, fg), 1200);
  await png(`${exports}/logo/original/pz-logo-4x1-1200x300${suffix}.png`, svg(1200, 300, rect(1200, 300, bg) +
    mark(40, 60, 450, fg) + label(570, 158, 'population.town', 36, fg)));
  const mode = dark ? 'dark' : 'light';
  await png(`${exports}/logo/variants/pz-logo-compact-${mode}.png`, svg(1200, 300, rect(1200, 300, bg) +
    mark(40, 60, 450, fg) + label(570, 158, 'population.town', 36, fg)));
  await png(`${exports}/logo/variants/pz-logo-stacked-${mode}.png`, svg(1200, 900, rect(1200, 900, bg) +
    mark(210, 180, 780, fg) + label(360, 610, 'population.town', 36, fg)));
  await png(`${exports}/logo/variants/pz-logo-badge-${mode}.png`, icon(bg, fg), 1200);
}
console.log('POZ: generated web, native, adaptive, favicon, sharing and preview assets.');
