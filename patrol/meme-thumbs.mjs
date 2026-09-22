// 벽 섬네일 채우기 — thumb 이 없는 짤(원본 PNG/JPG/WebP, 유튜브 썸네일 제외)을 480px JPEG 로 줄여 pz-assets 에 올리고 memes.thumb 에 적는다.
// 한 번 돌리면 끝(이후는 올릴 때 브라우저·make-memes 가 만든다). 실행: node meme-thumbs.mjs [--limit N] [--dry-run]   (PZ_ASSETS_PAT 또는 gh auth)
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import { d1, rows } from './d1.mjs';

const require = createRequire(import.meta.url);
const { createCanvas, loadImage } = require('../site/node_modules/@napi-rs/canvas');
const log = (m) => console.log(`[thumbs] ${m}`);
const DRY = process.argv.includes('--dry-run');
const LIMIT = Number(process.argv[process.argv.indexOf('--limit') + 1]) || 400;
const esc = (s) => String(s).replace(/'/g, "''");
const UA = { 'user-agent': 'pz-patrol (population.town)' };

let ghToken = process.env.PZ_ASSETS_PAT || process.env.GITHUB_PAT || null;
async function upload(key, buf) {
  if (!ghToken) { try { ghToken = execSync('gh auth token', { encoding: 'utf8' }).trim(); } catch { /* 아래 */ } }
  if (!ghToken) throw new Error('no PZ_ASSETS_PAT');
  const up = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
    method: 'PUT', headers: { authorization: `Bearer ${ghToken}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-patrol' },
    body: JSON.stringify({ message: `thumb: ${key}`, content: Buffer.from(buf).toString('base64') }),
  });
  if (!up.ok) throw new Error(`github upload ${up.status}`);
  return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
}
async function thumbOf(buf, w = 480) {
  const im = await loadImage(buf); const k = Math.min(1, w / im.width);
  const c = createCanvas(Math.max(1, Math.round(im.width * k)), Math.max(1, Math.round(im.height * k))); const ctx = c.getContext('2d');
  ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, c.width, c.height); ctx.drawImage(im, 0, 0, c.width, c.height);
  return c.toBuffer('image/jpeg', 82);
}

const list = await rows(`SELECT id, png, kind FROM memes WHERE hidden = 0 AND thumb IS NULL AND kind <> 'video' AND substr(png, 1, 50) = 'https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/' ORDER BY id DESC LIMIT ${LIMIT}`);
log(`${list.length} without a thumb`);
let ok = 0, fail = 0;
for (const m of list) {
  try {
    const res = await fetch(m.png, { headers: UA }); if (!res.ok) throw new Error(`fetch ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length < 120 * 1024 && m.kind !== 'gif') { await d1(`UPDATE memes SET thumb = png WHERE id = ${m.id}`); ok++; continue; } // 이미 작으면 원본을 그대로 섬네일로
    const jpg = await thumbOf(buf);
    if (DRY) { log(`#${m.id} ${(buf.length / 1024).toFixed(0)}KB → ${(jpg.length / 1024).toFixed(0)}KB`); ok++; continue; }
    const name = m.png.split('/').pop().replace(/\.[a-z0-9]+$/i, '');
    const url = await upload(`memes/thumbs/${name}-t.jpg`, jpg);
    await d1(`UPDATE memes SET thumb = '${esc(url)}' WHERE id = ${m.id}`);
    ok++; if (ok % 10 === 0) log(`${ok}/${list.length}`);
  } catch (e) { fail++; log(`#${m.id} 실패: ${e.message.slice(0, 80)}`); }
}
log(`done: ${ok} ok, ${fail} failed`);
