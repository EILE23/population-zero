// Native SVG-to-icon export: node brand/poz/favicon/generate.mjs [sharp path]
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const require = createRequire(import.meta.url);
const sharp = require(process.argv[2] || 'sharp');
const dir = dirname(fileURLToPath(import.meta.url));
const root = resolve(dir, '../../..');
const source = await readFile(resolve(dir, 'null.svg'));
const write = async (path, value) => { const dest = resolve(root, path); await mkdir(dirname(dest), { recursive: true }); await writeFile(dest, value); };
const png = async (size) => sharp(source, { density: 384 }).resize(size, size).png().toBuffer();
await write('site/src/app/icon.svg', source);
for (const size of [16, 32, 48, 64, 180, 256, 512]) {
  const bytes = await png(size);
  await write(`brand/poz/favicon/null-${size}.png`, bytes);
  if (size <= 64) await write(`site/public/brand/favicon-${size}.png`, bytes);
  if (size === 64) await write('app/assets/favicon.png', bytes);
  if (size === 180) {
    // Apple web clips are opaque, square files; iOS applies the final mask.
    await write('site/src/app/apple-icon.png', await sharp(bytes).flatten({ background: '#F5F5F7' }).removeAlpha().png().toBuffer());
  }
}
const sizes = [16, 32, 48];
const images = await Promise.all(sizes.map(png));
const header = Buffer.alloc(6 + 16 * sizes.length);
header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
let offset = header.length;
images.forEach((data, i) => {
  const p = 6 + i * 16;
  header[p] = sizes[i]; header[p + 1] = sizes[i];
  header.writeUInt16LE(1, p + 4); header.writeUInt16LE(32, p + 6);
  header.writeUInt32LE(data.length, p + 8); header.writeUInt32LE(offset, p + 12);
  offset += data.length;
});
const ico = Buffer.concat([header, ...images]);
await write('site/src/app/favicon.ico', ico);
await write('brand/poz/favicon/favicon.ico', ico);
const inner = source.toString().replace(/<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const sampleRows = [0, 110].map((top, row) => [16, 32, 48, 64].map((size, i) =>
  `<svg x="${24 + i * 118}" y="${top + 18}" width="${size}" height="${size}" viewBox="0 0 64 64">${inner}</svg>` +
  `<text x="${24 + i * 118}" y="${top + 98}" font-family="Arial" font-size="11" fill="${row ? '#FFFFFF' : '#1B0C15'}">${size}px</text>`).join('')).join('');
const proof = `<svg xmlns="http://www.w3.org/2000/svg" width="496" height="220"><rect width="496" height="220" fill="#FFFFFF"/><rect y="110" width="496" height="110" fill="#1B0C15"/>${sampleRows}</svg>`;
await write('brand/poz/favicon/preview.png', await sharp(Buffer.from(proof)).png().toBuffer());
console.log('Null favicon: SVG, 16/32/48 ICO, PNG sizes, Apple web clip and Expo web favicon.');
