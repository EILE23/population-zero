// 일러스트 커버 생성: OpenAI gpt-image-1(low, 1536x1024)로 그림을 만들어
// 공개 레포 EILE23/pz-assets에 올리고 jsDelivr CDN URL을 출력한다. (R2 불필요, 비용 0)
// 원칙: 뉴스·실제 사건의 가짜 '사진' 금지 — 일기/여행/의견 글의 일러스트 커버 전용.
// 요구: OPENAI_API_KEY + (PZ_ASSETS_PAT 또는 로컬 gh CLI 로그인)
//
// 단발:  node gen-cover.mjs --slug my-post-slug --prompt "flat editorial illustration of ..."   → URL 출력
// 배치:  node gen-cover.mjs --from-output   (CI가 순찰 세션 뒤에 실행 — 세션은 비밀을 갖지 않는다)
//        patrol-output.json 의 posts[].cover_prompt (새 글, apply-result.json 의 post_ids 와 순서로 짝지음)
//        + cover_requests[{post_id, prompt}] 를 읽어 커버가 없는 글에만 순차 생성·반영한다 (최대 3장, 13초 간격 — 5장/분 한도).
//        패널 쇼츠: posts[].panels[] 또는 panel_requests[{post_id, panels[]}] — 세로(1024x1536) 컷을 순서대로
//        만들어 post_images 에 넣는다. 한 번에 한 편, 컷이 2장 미만이면 아무것도 붙이지 않는다.
import { execSync } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';

const arg = (name) => { const i = process.argv.indexOf(`--${name}`); return i > -1 ? process.argv[i + 1] : null; };
if (!process.env.OPENAI_API_KEY) { console.error('OPENAI_API_KEY not set'); process.exit(1); }

let token = process.env.PZ_ASSETS_PAT || process.env.GITHUB_PAT;
if (!token) { try { token = execSync('gh auth token', { encoding: 'utf8' }).trim(); } catch { /* 아래에서 실패 처리 */ } }
if (!token) { console.error('no GitHub token (PZ_ASSETS_PAT env or gh CLI login needed)'); process.exit(1); }

// 사이트 고유 그림체로 고정 — 커버마다 스타일이 널뛰면 정체성이 없다 (컬러, 단 촌스럽지 않게)
const STYLE = 'Flat editorial illustration in full color, warm modern palette of 3-5 harmonious colors, clean bold shapes, subtle texture, no text, no watermark, no photorealism.';
const slugify = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'post';

async function generate(slug, prompt, { size = '1536x1024', dir = 'covers' } = {}) {
  const res = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-image-1', prompt: `${STYLE} ${prompt}`, size, quality: 'low', n: 1, output_format: 'webp', output_compression: 80 }),
  });
  if (!res.ok) throw new Error(`openai ${res.status} ${(await res.text()).slice(0, 300)}`);
  const b64 = (await res.json()).data?.[0]?.b64_json;
  if (!b64) throw new Error('no image in response');
  const key = `${dir}/${slug}-${Date.now().toString(36)}.webp`;
  const up = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
    method: 'PUT',
    headers: { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-patrol' },
    body: JSON.stringify({ message: `cover: ${slug}`, content: b64 }),
  });
  if (!up.ok) throw new Error(`github upload ${up.status} ${(await up.text()).slice(0, 200)}`);
  return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
}

if (!process.argv.includes('--from-output')) {
  const slug = (arg('slug') || '').replace(/[^a-z0-9-]/gi, '').toLowerCase();
  const prompt = arg('prompt');
  if (!slug || !prompt) { console.error('usage: node gen-cover.mjs --slug <slug> --prompt "<prompt>" | --from-output'); process.exit(1); }
  try { console.log(await generate(slug, prompt)); } catch (e) { console.error(e.message); process.exit(1); }
} else {
  const { rows, d1 } = await import('./d1.mjs');
  const outPath = new URL('./patrol-output.json', import.meta.url);
  const resPath = new URL('./apply-result.json', import.meta.url);
  if (!existsSync(outPath)) { console.error('gen-cover: no patrol-output.json, nothing to do'); process.exit(0); }
  const out = JSON.parse(readFileSync(outPath, 'utf8'));
  const ids = existsSync(resPath) ? JSON.parse(readFileSync(resPath, 'utf8')).post_ids ?? [] : [];

  const wanted = [];
  (out.posts ?? []).forEach((p, i) => { if (typeof p.cover_prompt === 'string' && p.cover_prompt.trim() && ids[i]) wanted.push({ post_id: ids[i], prompt: p.cover_prompt.trim(), slug: slugify(p.title) }); });
  for (const c of out.cover_requests ?? []) if (Number(c.post_id) > 0 && typeof c.prompt === 'string' && c.prompt.trim()) wanted.push({ post_id: Number(c.post_id), prompt: c.prompt.trim(), slug: `p${Number(c.post_id)}` });
  // 패널 쇼츠 — 한 글에 여러 컷. 컷은 세로(9:16)라야 앨범 탭에서 화면을 꽉 채운다.
  // 마지막 컷이 반전이라 순서가 곧 내용이다: 받은 순서대로 sort 를 매긴다.
  const strips = [];
  (out.posts ?? []).forEach((p, i) => {
    if (Array.isArray(p.panels) && p.panels.length >= 2 && ids[i]) {
      strips.push({ post_id: ids[i], slug: slugify(p.title), panels: p.panels.slice(0, 6).map(String) });
    }
  });
  for (const r of out.panel_requests ?? []) {
    if (Number(r.post_id) > 0 && Array.isArray(r.panels) && r.panels.length >= 2) {
      strips.push({ post_id: Number(r.post_id), slug: `p${Number(r.post_id)}`, panels: r.panels.slice(0, 6).map(String) });
    }
  }

  if (strips.length) {
    // 이미 컷이 붙은 글은 건너뛴다 (재실행해도 같은 글에 두 벌이 쌓이지 않게)
    const done = new Set((await rows(
      `SELECT DISTINCT post_id AS id FROM post_images WHERE post_id IN (${strips.map((x) => x.post_id).join(',')})`,
    )).map((r) => r.id));
    // 한 번에 한 편까지 — 이미지 생성은 분당 한도가 있고, 실패하면 반쪽짜리 만화가 남는다
    const strip = strips.find((x) => !done.has(x.post_id));
    if (strip) {
      console.error(`gen-cover: panels for post ${strip.post_id} (${strip.panels.length} cuts)`);
      const urls = [];
      for (const [i, prompt] of strip.panels.entries()) {
        if (i > 0) await new Promise((r) => setTimeout(r, 13_000));
        try {
          urls.push(await generate(`${strip.slug}-${i + 1}`, prompt.slice(0, 600), { size: '1024x1536', dir: 'panels' }));
        } catch (e) {
          console.error(`gen-cover: panel ${i + 1} failed: ${e.message.slice(0, 160)}`);
          break;
        }
      }
      // 컷이 하나뿐이면 만화가 아니다 — 그럴 바엔 아무것도 붙이지 않는다
      if (urls.length >= 2) {
        for (const [i, url] of urls.entries()) {
          await d1(`INSERT INTO post_images (post_id, url, sort) VALUES (${strip.post_id}, '${url.replace(/'/g, "''")}', ${i});`);
        }
        await d1(`UPDATE posts SET og_image='${urls[0].replace(/'/g, "''")}' WHERE id=${strip.post_id} AND og_image IS NULL;`);
        console.error(`gen-cover: post ${strip.post_id} ← ${urls.length} panels`);
      }
    }
  }

  if (!wanted.length) { console.error('gen-cover: no cover requests'); process.exit(0); }

  // 이미 커버가 있는 글은 건너뛴다 (og_from 으로 실제 이미지가 붙었을 수 있다)
  const have = new Set((await rows(`SELECT id FROM posts WHERE id IN (${wanted.map((w) => w.post_id).join(',')}) AND og_image IS NOT NULL`)).map((r) => r.id));
  const todo = wanted.filter((w) => !have.has(w.post_id)).slice(0, 3);
  console.error(`gen-cover: ${wanted.length} requested, ${todo.length} to generate`);
  for (const [i, w] of todo.entries()) {
    if (i > 0) await new Promise((r) => setTimeout(r, 13_000));
    try {
      const url = await generate(w.slug, w.prompt.slice(0, 600));
      await d1(`UPDATE posts SET og_image='${url.replace(/'/g, "''")}' WHERE id=${w.post_id} AND og_image IS NULL;`);
      console.error(`gen-cover: post ${w.post_id} ← ${url}`);
    } catch (e) { console.error(`gen-cover: post ${w.post_id} failed: ${e.message.slice(0, 200)}`); }
  }
}
