// 일러스트 커버 생성: OpenAI gpt-image-1(low, 1536x1024)로 그림을 만들어 R2에 올리고 공개 URL을 출력.
// 사용: node gen-cover.mjs --slug my-post-slug --prompt "flat editorial illustration of ..."
// 원칙: 뉴스·실제 사건의 가짜 '사진' 금지 — 일기/여행/의견 글의 일러스트 커버 전용.
// 요구: OPENAI_API_KEY 환경변수, R2 활성화 + patrol/.r2-public 파일(공개 base URL 한 줄).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const arg = (name) => { const i = process.argv.indexOf(`--${name}`); return i > -1 ? process.argv[i + 1] : null; };
const slug = (arg('slug') || '').replace(/[^a-z0-9-]/gi, '').toLowerCase();
const prompt = arg('prompt');
if (!slug || !prompt) { console.error('usage: node gen-cover.mjs --slug <slug> --prompt "<prompt>"'); process.exit(1); }
if (!process.env.OPENAI_API_KEY) { console.error('OPENAI_API_KEY not set'); process.exit(1); }

const baseFile = new URL('./.r2-public', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
if (!existsSync(baseFile)) { console.error('patrol/.r2-public missing — enable R2 in the Cloudflare dashboard, then save the pub-*.r2.dev base URL there'); process.exit(1); }
const publicBase = readFileSync(baseFile, 'utf8').trim().replace(/\/$/, '');

// 사이트 고유 그림체로 고정 — 커버마다 스타일이 널뛰면 정체성이 없다
const STYLE = 'Flat editorial illustration, muted ink-and-paper palette (near-monochrome with one restrained accent), clean shapes, no text, no watermark, no photorealism.';

const res = await fetch('https://api.openai.com/v1/images/generations', {
  method: 'POST',
  headers: { authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'content-type': 'application/json' },
  body: JSON.stringify({ model: 'gpt-image-1', prompt: `${STYLE} ${prompt}`, size: '1536x1024', quality: 'low', n: 1 }),
});
if (!res.ok) { console.error('openai error', res.status, (await res.text()).slice(0, 300)); process.exit(1); }
const b64 = (await res.json()).data?.[0]?.b64_json;
if (!b64) { console.error('no image in response'); process.exit(1); }

const tmp = new URL(`./cover-${slug}.png`, import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
writeFileSync(tmp, Buffer.from(b64, 'base64'));
const key = `covers/${slug}-${Date.now().toString(36)}.png`;
execSync(`npx wrangler r2 object put "pz-images/${key}" --file "${tmp}" --content-type image/png --remote`,
  { cwd: new URL('../site/', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'), stdio: ['ignore', 'ignore', 'inherit'] });
console.log(`${publicBase}/${key}`);
