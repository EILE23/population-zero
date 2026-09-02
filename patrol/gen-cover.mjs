// 일러스트 커버 생성: OpenAI gpt-image-1(low, 1536x1024)로 그림을 만들어
// 공개 레포 EILE23/pz-assets에 올리고 jsDelivr CDN URL을 출력한다. (R2 불필요, 비용 0)
// 사용: node gen-cover.mjs --slug my-post-slug --prompt "flat editorial illustration of ..."
// 원칙: 뉴스·실제 사건의 가짜 '사진' 금지 — 일기/여행/의견 글의 일러스트 커버 전용.
// 요구: OPENAI_API_KEY + (PZ_ASSETS_PAT 또는 로컬 gh CLI 로그인)
import { execSync } from 'node:child_process';

const arg = (name) => { const i = process.argv.indexOf(`--${name}`); return i > -1 ? process.argv[i + 1] : null; };
const slug = (arg('slug') || '').replace(/[^a-z0-9-]/gi, '').toLowerCase();
const prompt = arg('prompt');
if (!slug || !prompt) { console.error('usage: node gen-cover.mjs --slug <slug> --prompt "<prompt>"'); process.exit(1); }
if (!process.env.OPENAI_API_KEY) { console.error('OPENAI_API_KEY not set'); process.exit(1); }

let token = process.env.PZ_ASSETS_PAT || process.env.GITHUB_PAT;
if (!token) { try { token = execSync('gh auth token', { encoding: 'utf8' }).trim(); } catch { /* 아래에서 실패 처리 */ } }
if (!token) { console.error('no GitHub token (PZ_ASSETS_PAT env or gh CLI login needed)'); process.exit(1); }

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

const key = `covers/${slug}-${Date.now().toString(36)}.png`;
const up = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
  method: 'PUT',
  headers: { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-patrol' },
  body: JSON.stringify({ message: `cover: ${slug}`, content: b64 }),
});
if (!up.ok) { console.error('github upload error', up.status, (await up.text()).slice(0, 200)); process.exit(1); }
console.log(`https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`);
