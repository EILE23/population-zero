// 만들어진 게임 폴더의 정적 검사 — build-game.yml 의 ship 잡이 게이트 앞에서 돌린다. 자격증명 없음, 실행 없음.
//   node patrol/games-check.mjs <slug> [repo-root]
// 게임은 자기 폴더 + 엔진 + react 만 가져올 수 있고(GAMES.md), 방(room) 말고는 네트워크·저장소·평가·DOM 주입이 없다.
// 에이전트가 무엇을 썼든 이 검사가 통과하지 못하면 배포되지 않는다 — 규칙을 지켰다는 말이 아니라 코드가 증거다.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const [slug, root = '.'] = process.argv.slice(2);
if (!slug || !/^[a-z0-9][a-z0-9-]{1,40}$/.test(slug)) { console.error('usage: games-check.mjs <slug> [repo-root]'); process.exit(2); }

const dir = path.join(root, 'site/src/features/games', slug);
const MAX_FILES = 12, MAX_BYTES = 120_000, MAX_TOTAL = 400_000;
const ALLOWED_IMPORT = [/^react$/, /^@\/features\/games\/engine$/, /^\.\.\/registry$/, /^\.\/[A-Za-z0-9_-]+$/];
// 이름만으로 잡는다 — 우회(문자열 조합·globalThis 접근)는 globalThis·window[...] 도 막아서 좁힌다
const FORBIDDEN = [
  [/\bfetch\s*\(/, 'network: fetch'], [/\bXMLHttpRequest\b/, 'network: XMLHttpRequest'], [/\bWebSocket\b/, 'network: WebSocket (use connectRoom)'],
  [/\bEventSource\b/, 'network: EventSource'], [/\bsendBeacon\b/, 'network: sendBeacon'], [/\bnew\s+Worker\b|\bSharedWorker\b|\bimportScripts\b/, 'workers'],
  [/\/api\//, 'api path'], [/\b(localStorage|sessionStorage|indexedDB)\b/, 'storage'], [/\bdocument\.cookie\b/, 'cookie'],
  [/\beval\s*\(/, 'eval'], [/\bnew\s+Function\b|\bFunction\s*\(/, 'Function constructor'], [/\bdangerouslySetInnerHTML\b/, 'html injection'],
  [/\binnerHTML\b|\bouterHTML\b|\binsertAdjacentHTML\b|\bdocument\.write\b/, 'html injection'], [/\bimport\s*\(/, 'dynamic import'], [/\brequire\s*\(/, 'require'],
  [/\bprocess\.env\b/, 'env'], [/<script\b|<iframe\b|<object\b|<embed\b/i, 'embedded tag'], [/\bwindow\.open\b|\blocation\.(href|assign|replace)\b|\blocation\s*=/, 'navigation'],
  [/\bpostMessage\b/, 'postMessage'], [/\bglobalThis\b|\bwindow\s*\[/, 'global escape'], [/__proto__|\bconstructor\s*\[/, 'prototype access'],
  [/\bdocument\.createElement\s*\(\s*['"`](script|iframe|link|img|form)/i, 'element injection'], [/\bnavigator\.(clipboard|geolocation|mediaDevices|credentials)\b/, 'device access'],
  [/\bNotification\b/, 'notifications'], [/\bcrypto\.subtle\b/, 'crypto'],
];
const WARN = [[/\bMath\.random\s*\(/, 'Math.random — fine for local juice only, never for shared state'], [/\bDate\.now\s*\(/, 'Date.now — use room.now() for shared time']];

const problems = [];
const warnings = [];
let files;
try { files = readdirSync(dir).filter((f) => !f.startsWith('.')); } catch { console.error(`no game folder: ${dir}`); process.exit(1); }
if (!files.includes('Game.tsx')) problems.push('Game.tsx is missing');
if (files.length > MAX_FILES) problems.push(`${files.length} files (max ${MAX_FILES})`);
let total = 0;
for (const f of files) {
  const p = path.join(dir, f);
  if (statSync(p).isDirectory()) { problems.push(`${f}/ — no subfolders`); continue; }
  if (!/\.(ts|tsx)$/.test(f)) { problems.push(`${f} — only .ts/.tsx (no assets, no json, no css)`); continue; }
  const src = readFileSync(p, 'utf8');
  total += src.length;
  if (src.length > MAX_BYTES) problems.push(`${f} — ${src.length} bytes (max ${MAX_BYTES})`);
  if (/[\u0000-\u0008\u000b\u000e-\u001f]/.test(src)) problems.push(`${f} — control characters`);
  for (const m of src.matchAll(/(?:^|\n)\s*import\s+(?:type\s+)?[^'"]*?from\s*['"]([^'"]+)['"]|(?:^|\n)\s*import\s*['"]([^'"]+)['"]|\bexport\s+[^'"]*?from\s*['"]([^'"]+)['"]/g)) {
    const id = m[1] ?? m[2] ?? m[3];
    if (!ALLOWED_IMPORT.some((re) => re.test(id))) problems.push(`${f} — import '${id}' (allowed: react, @/features/games/engine, ../registry, ./sibling)`);
  }
  const stripped = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:\\])\/\/[^\n]*/g, '$1'); // 주석 속 단어로 막히지 않게 — 그러나 문자열 속은 그대로 본다
  for (const [re, why] of FORBIDDEN) { const hit = stripped.match(re); if (hit) problems.push(`${f} — ${why}: "${hit[0]}"`); }
  for (const [re, why] of WARN) if (re.test(stripped)) warnings.push(`${f} — ${why}`);
}
if (total > MAX_TOTAL) problems.push(`${total} bytes total (max ${MAX_TOTAL})`);
if (files.includes('Game.tsx')) {
  const game = readFileSync(path.join(dir, 'Game.tsx'), 'utf8');
  if (!/^['"]use client['"]/.test(game.trimStart())) problems.push(`Game.tsx — must start with 'use client'`);
  if (!/export\s+default\s+function\s+Game\b/.test(game)) problems.push('Game.tsx — must `export default function Game`');
}

for (const w of warnings) console.log(`warn: ${w}`);
if (problems.length) { console.error(`games-check ${slug}: ${problems.length} problem(s)`); for (const p of problems) console.error(` - ${p}`); process.exit(1); }
console.log(`games-check ${slug}: ok (${files.length} files, ${total} bytes)`);
