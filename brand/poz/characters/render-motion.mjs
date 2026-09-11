// Encode cutout motion from the original, unmodified character PNGs.
// node brand/poz/characters/render-motion.mjs <sharp module> <ffmpeg executable>
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const require = createRequire(import.meta.url);
const sharp = require(process.argv[2] || 'sharp');
const ffmpeg = process.argv[3] || process.env.POZ_FFMPEG || 'ffmpeg';
const dir = dirname(fileURLToPath(import.meta.url));
const out = resolve(dir, 'motion');
await mkdir(out, { recursive: true });
const cast = [
  ['iris', 'welcome', 'Iris', 'I looked into it.'],
  ['bracket', 'thinking', 'Bracket', 'Actually—'],
  ['cache', 'receipt', 'Cache', 'I have the receipts.'],
  ['null', 'sleeping', 'Null', 'No statement.'],
];
const run = (args) => {
  const p = spawnSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', ...args], { encoding: 'utf8', windowsHide: true });
  if (p.error) throw p.error;
  if (p.status !== 0) throw new Error(p.stderr);
};
const logo = (await readFile(resolve(dir, '../wordmark.svg'), 'utf8')).match(/<path\b[^>]*\/>/g).join('');
const text = (x, y, value, size, font = 'Arial', fill = '#1B0C15') => `<text x="${x}" y="${y}" font-family="${font}" font-size="${size}" fill="${fill}">${value}</text>`;
for (const [name, pose, label, line] of cast) {
  // Two intentionally held key poses, not frame-by-frame character animation.
  // Four-second loop ends on the starting pose and transform.
  const sway = name === 'null' ? '0' : name === 'bracket' ? '0.016*sin(2*PI*t/4)' : '0.025*sin(2*PI*t/4)';
  const loop = resolve(out, `${name}-loop.mp4`);
  run(['-loop', '1', '-framerate', '24', '-i', resolve(dir, `${name}.png`),
    '-loop', '1', '-framerate', '24', '-i', resolve(dir, `${name}-${pose}.png`),
    '-filter_complex',
    `color=c=0xF5F5F7:s=640x640:r=24:d=4[bg];` +
    `[0:v]scale=600:600,format=rgba,rotate='${sway}':c=none[a];` +
    `[1:v]scale=600:600,format=rgba,rotate='${sway}':c=none[b];` +
    `[bg][a]overlay=20:20:enable='lt(t,1)+gte(t,3)'[first];` +
    `[first][b]overlay=20:'20-3*sin(PI*(t-1)/2)':enable='gte(t,1)*lt(t,3)',format=yuv420p[v]`,
    '-map', '[v]', '-t', '4', '-an', '-c:v', 'libx264', '-crf', '18', '-preset', 'fast', '-movflags', '+faststart', loop]);
  run(['-i', loop, '-filter_complex', 'fps=12,scale=400:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4', '-loop', '0', resolve(out, `${name}-loop.gif`)]);
  for (const vertical of [false, true]) {
    const w = vertical ? 1080 : 1280, h = vertical ? 1920 : 720;
    const titleY = vertical ? 380 : 294;
    const content = `<rect width="${w}" height="${h}" fill="#F5F5F7"/>` +
      `<g fill="#1B0C15" transform="translate(72 56) scale(.20)">${logo}</g>` +
      text(72, vertical ? 280 : 200, 'THE LOCALS', 17, 'monospace', '#7B526C') +
      text(72, titleY, label, vertical ? 90 : 80, 'Georgia') +
      text(72, titleY + 64, line, 30, 'Georgia') +
      text(72, h - 76, 'Trends. Stories. Conversation.', 22) +
      text(72, h - 40, 'population.town', 19, 'Arial', '#7B526C');
    const card = resolve(out, `${name}-${vertical ? 'vertical' : 'wide'}-card.png`);
    await sharp(Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${content}</svg>`)).png().toFile(card);
    const clip = resolve(out, `${name}-${vertical ? 'vertical' : 'wide'}.mp4`);
    run(['-loop', '1', '-framerate', '24', '-i', card, '-i', loop,
      '-filter_complex', vertical ? '[1:v]scale=1000:1000[a];[0:v][a]overlay=40:640,format=yuv420p[v]' : '[0:v][1:v]overlay=640:36,format=yuv420p[v]',
      '-map', '[v]', '-t', '4', '-an', '-c:v', 'libx264', '-crf', '20', '-preset', 'fast', '-movflags', '+faststart', clip]);
  }
  console.log(`${label}: loop MP4/GIF and promo shots rendered.`);
}
for (const vertical of [false, true]) {
  const mode = vertical ? 'vertical' : 'wide';
  const args = cast.flatMap(([name]) => ['-i', resolve(out, `${name}-${mode}.mp4`)]);
  run([...args, '-filter_complex', '[0:v][1:v][2:v][3:v]concat=n=4:v=1:a=0[v]', '-map', '[v]', '-an',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'fast', '-movflags', '+faststart', resolve(out, `poz-locals-${mode}.mp4`)]);
}
await writeFile(resolve(out, 'README.md'), '# POZ motion exports\n\nFour 4-second cutout loops (MP4 and GIF) plus 16-second wide and vertical promo montages.\nNo audio. Opaque surface background (#F5F5F7). PNG sources are not modified.\nTwo held poses with gentle whole-illustration transforms; not articulated or frame-by-frame animation.\nUse native/CSS character components in the product, not autoplaying video loops.\n');
