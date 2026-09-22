// 이미 게시된 주민 짤 가운데 글자가 그림 밖으로 나가거나 겹치는 것을 찾아(기본: 보고만) 다시 그린다.
//
// 새 fit 규칙(site/src/lib/meme-draw.ts fitMemeText)은 새 짤에만 적용된다. 옛 짤은 저장된 style 로 다시 그릴 수 있으므로
// 같은 규칙으로 맞춘 뒤 PNG·섬네일을 새로 올리고 style 을 갱신한다. 원본 PNG 는 지우지 않는다(리믹스가 옛 png 를 가리킬 수 있다).
//
// 실행: node --experimental-strip-types refit-memes.mjs            → 겹침·넘침 목록만 (쓰기 없음)
//       node --experimental-strip-types refit-memes.mjs --apply    → 다시 그려 올리고 style 갱신 (OPENAI 불필요, PZ_ASSETS_PAT 필요)
//       --limit N (기본 40)  --id N (한 장만)
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { d1, rows } from './d1.mjs';
import { cleanStyle } from '../site/src/lib/memes.ts';
import { drawMemeText, fitMemeText, FONT_FILES, setFont, textBounds, wrapRows } from '../site/src/lib/meme-draw.ts';

const require = createRequire(import.meta.url);
const { createCanvas, loadImage, GlobalFonts } = require('../site/node_modules/@napi-rs/canvas');
const arg = (n) => { const i = process.argv.indexOf(`--${n}`); return i > -1 ? process.argv[i + 1] : null; };
const APPLY = process.argv.includes('--apply');
const LIMIT = Number(arg('limit') ?? 40);
const ONLY = arg('id');
const W = 900;
const UA = { 'user-agent': 'pz-patrol (population.town)' };
const esc = (s) => String(s).replace(/'/g, "''");
const log = (m) => console.log(`[refit] ${m}`);

async function fonts() {
  const dir = path.join(os.tmpdir(), 'pz-meme-fonts'); mkdirSync(dir, { recursive: true });
  for (const [family, url] of Object.entries(FONT_FILES)) {
    const file = path.join(dir, `${family.replace(/\s+/g, '')}.ttf`);
    if (!existsSync(file)) writeFileSync(file, Buffer.from(await (await fetch(url, { headers: UA })).arrayBuffer()));
    GlobalFonts.registerFromPath(file, family);
  }
}

/** 글자 상자(그림 좌표) — 넘침·겹침 판정용 */
function box(ctx, t, Wc, Hc, padK = 0.3) {
  const px = t.size * Hc; setFont(ctx, t, px);
  const bb = textBounds(ctx, wrapRows(ctx, t, Wc), px); const pad = px * padK;
  return { x0: t.x * Wc + bb.x - pad, x1: t.x * Wc + bb.x + bb.w + pad, y0: t.y * Hc + bb.y - pad, y1: t.y * Hc + bb.y + bb.h + pad };
}
// 넘침은 fitMemeText 와 같은 여백(0.15)으로 잰다 — 겹침 판정의 넓은 여백(0.3)으로 재면 맞춘 글자도 넘친 것처럼 보인다
const overflows = (b, Wc, Hc) => b.x0 < -3 || b.y0 < -3 || b.x1 > Wc + 3 || b.y1 > Hc + 3;
const hits = (a, b) => a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;

/** 글자 상자들이 겹치면 뒤의 것을 아래(안 되면 위)로 민다. 네 번 밀어도 겹치면 포기 — make-memes.mjs 와 같다 */
function separate(ctx, texts, Wc, Hc) {
  const out = [];
  for (const t0 of texts) {
    let t = { ...t0 };
    for (let tries = 0; tries < 4; tries++) {
      const b = box(ctx, t, Wc, Hc); const other = out.map((o) => box(ctx, o, Wc, Hc)).find((o) => hits(o, b));
      if (!other) break;
      const down = (other.y1 - b.y0 + 8) / Hc, up = (b.y1 - other.y0 + 8) / Hc;
      const ny = t.y + down; const uy = t.y - up;
      t = { ...t, y: ny < 0.98 ? ny : uy };
      if (tries === 3) return null;
    }
    out.push(t);
  }
  return out;
}

let ghToken = process.env.PZ_ASSETS_PAT || process.env.GITHUB_PAT || null;
async function upload(key, buf) {
  if (!ghToken) { try { ghToken = execSync('gh auth token', { encoding: 'utf8' }).trim(); } catch { /* */ } }
  if (!ghToken) throw new Error('no PZ_ASSETS_PAT');
  const up = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
    method: 'PUT', headers: { authorization: `Bearer ${ghToken}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-patrol' },
    body: JSON.stringify({ message: `meme refit: ${key}`, content: Buffer.from(buf).toString('base64') }),
  });
  if (!up.ok) throw new Error(`github upload ${up.status}`);
  return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
}

async function main() {
  await fonts();
  const where = ONLY ? `m.id = ${Number(ONLY)}` : `m.resident_id IS NOT NULL AND m.kind = 'image' AND m.hidden = 0`;
  const memes = await rows(`SELECT m.id, m.style, m.png, r.handle FROM memes m JOIN residents r ON r.id = m.resident_id WHERE ${where} ORDER BY m.id DESC LIMIT ${LIMIT}`);
  let bad = 0, fixed = 0;
  for (const m of memes) {
    let style; try { style = cleanStyle(JSON.parse(m.style)); } catch { continue; }
    const panels = style.panels.filter(Boolean);
    if (!style.texts.length || !panels.length) continue;
    // 캔버스 크기는 첫 컷 비율 × 컷 수 (make-memes 의 render 와 같은 규칙)
    let im; try { im = await loadImage(Buffer.from(await (await fetch(panels[0], { headers: UA })).arrayBuffer())); } catch { log(`#${m.id} 바탕을 못 받음 — 건너뜀`); continue; }
    const h1 = Math.round(W * im.height / im.width); const Hc = h1 * panels.length;
    const c = createCanvas(W, Hc); const ctx = c.getContext('2d');
    const boxes = style.texts.map((t) => box(ctx, t, W, Hc));
    const over = style.texts.map((t) => box(ctx, t, W, Hc, 0.15)).some((b) => overflows(b, W, Hc));
    const overlap = boxes.some((a, i) => boxes.some((b, j) => j > i && hits(a, b)));
    if (!over && !overlap) continue;
    bad++;
    // 넘침은 fit 으로, 겹침은 separate(make-memes 와 같은 규칙: 뒤의 것을 아래로, 안 되면 위로)로 — 둘 다 못 풀면 수동
    const fitted = style.texts.map((t) => fitMemeText(ctx, t, W, Hc));
    const sep = separate(ctx, fitted, W, Hc);
    const placed = sep ? sep.map((t) => fitMemeText(ctx, t, W, Hc)) : null;
    const still = !placed || placed.map((t) => box(ctx, t, W, Hc, 0.15)).some((b) => overflows(b, W, Hc))
      || placed.some((a, i) => placed.some((b, j) => j > i && hits(box(ctx, a, W, Hc), box(ctx, b, W, Hc))));
    log(`#${m.id} @${m.handle}: ${over ? '넘침 ' : ''}${overlap ? '겹침 ' : ''}→ ${still ? '맞춰도 넘침(수동)' : APPLY ? '다시 그림' : '맞출 수 있음'}`);
    if (!APPLY || still) continue;
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, W, Hc);
    for (let i = 0; i < panels.length; i++) {
      const pim = i === 0 ? im : await loadImage(Buffer.from(await (await fetch(panels[i], { headers: UA })).arrayBuffer()));
      ctx.drawImage(pim, 0, i * h1, W, h1);
      if (panels.length > 1) { ctx.fillStyle = '#111'; ctx.fillRect(0, (i + 1) * h1 - 2, W, 2); }
    }
    for (const t of placed) drawMemeText(ctx, t, W, Hc);
    const png = c.toBuffer('image/png');
    const k = Math.min(1, 480 / W); const tc = createCanvas(Math.round(W * k), Math.round(Hc * k)); const tctx = tc.getContext('2d');
    tctx.drawImage(await loadImage(png), 0, 0, tc.width, tc.height);
    const stamp = Date.now().toString(36);
    const url = await upload(`memes/refit-${m.id}-${stamp}.png`, png);
    const thumb = await upload(`memes/refit-${m.id}-${stamp}-t.jpg`, tc.toBuffer('image/jpeg', 82)).catch(() => null);
    const newStyle = JSON.stringify({ ...style, texts: placed });
    await d1(`UPDATE memes SET png = '${esc(url)}', thumb = ${thumb ? `'${esc(thumb)}'` : 'NULL'}, style = '${esc(newStyle)}' WHERE id = ${m.id};`);
    fixed++;
  }
  log(`${memes.length}장 검사 · 문제 ${bad}장${APPLY ? ` · 다시 그림 ${fixed}장` : ' (보고만 — --apply 로 다시 그린다)'}`);
}

await main();
