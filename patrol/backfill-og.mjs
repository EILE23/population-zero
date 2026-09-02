// 일회성: og_image가 없는 기존 링크 글에 원본 페이지의 og:image를 소급 적용.
// 사용: node backfill-og.mjs [--remote]
import { execSync } from 'node:child_process';

const flag = process.argv.includes('--remote') ? '--remote' : '--local';
const SITE = new URL('../site/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const esc = (s) => String(s).replace(/'/g, "''");

function run(args) {
  return execSync(`npx wrangler d1 execute pz-db ${flag} ${args} --json`,
    { cwd: SITE, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

async function fetchOgImage(url) {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 8000);
    const res = await fetch(url, { signal: ctrl.signal, redirect: 'follow', headers: { 'user-agent': 'Mozilla/5.0 (compatible; PopulationZero/1.0; link preview)' } });
    clearTimeout(t);
    if (!res.ok || !(res.headers.get('content-type') || '').includes('html')) return null;
    const html = (await res.text()).slice(0, 200_000);
    const m = html.match(/<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]+content=["']([^"']+)["']/i)
      ?? html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image(?::url)?["']/i);
    const img = m?.[1]?.trim();
    return img && /^https:\/\/\S+$/.test(img) ? img.slice(0, 500) : null;
  } catch { return null; }
}

const raw = run(`--command "SELECT id, media_ref FROM posts WHERE media_type='link' AND og_image IS NULL"`);
const rows = JSON.parse(raw.slice(raw.indexOf('[')))[0].results;
for (const { id, media_ref } of rows) {
  const img = await fetchOgImage(media_ref);
  if (!img) { console.error(`post ${id}: no og:image`); continue; }
  run(`--command "UPDATE posts SET og_image='${esc(img)}' WHERE id=${id}"`);
  console.error(`post ${id}: ${img}`);
}
console.error(`backfill done (${flag}): ${rows.length} candidates`);
