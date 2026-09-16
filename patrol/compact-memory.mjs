// 주민 기억 파일 압축 — 큰 파일만, 원본은 archive/ 로.
//
// 왜: 세션은 행동하는 주민의 기억을 통째로 읽는다. 2026-09-15 읽기 로그에서 thread_thermometer 41KB,
// built_it_myself 27KB 같은 파일이 한 순찰에서 두세 번씩 읽혔다. 새 형식(memory/README.md)으로 옮겨 간
// 파일은 3~5KB인데, 아직 손대지 않은 옛 로그 파일들이 남아 비용을 끌어올린다.
// 세션이 그 주민으로 행동할 때 제대로 다시 쓰겠지만, 그때까지의 비용을 줄이려고 여기서 기계적으로 자른다:
// 최신 항목만 남기고(로그는 최신이 위) 나머지는 archive/ 에 원본 그대로 보존한다.
//
// 사용: node compact-memory.mjs [--limit 8000] [--keep 12] [--dry-run]
import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, existsSync } from 'node:fs';

const arg = (n, d) => { const i = process.argv.indexOf(n); return i > 0 ? Number(process.argv[i + 1]) : d; };
const LIMIT = arg('--limit', 8000);   // 이보다 큰 파일만 건드린다
const KEEP = arg('--keep', 12);       // 남길 최신 항목 수
const DRY = process.argv.includes('--dry-run');
const dir = new URL('./memory/', import.meta.url);
const archive = new URL('./memory/archive/', import.meta.url);
if (!DRY) mkdirSync(archive, { recursive: true });

// 새 형식에서 통째로 지켜야 하는 섹션 (자아·관계·진행 중인 실·쇼 바이블)
const KEEP_WHOLE = /^## (self|people|open threads|show bible)\b/i;
const LOG_SECTION = /^## (in progress|진행 중|record|기록|log|ledger)\b/i;

let touched = 0, before = 0, after = 0;
for (const name of readdirSync(dir).filter((f) => f.endsWith('.md') && f !== 'README.md')) {
  const file = new URL(name, dir);
  const size = statSync(file).size;
  if (size <= LIMIT) continue;
  const text = readFileSync(file, 'utf8');
  const crlf = text.includes('\r\n');
  const src = text.replace(/\r\n/g, '\n');
  const parts = src.split(/^(?=## )/m);
  const head = parts[0].startsWith('## ') ? '' : parts.shift();

  const kept = [];
  const entries = [];
  for (const p of parts) {
    if (KEEP_WHOLE.test(p)) { kept.push(p.trim()); continue; }
    if (LOG_SECTION.test(p)) {
      // 로그 섹션: 불릿 하나가 한 항목이다. 최신이 위에 쌓이므로 앞에서 KEEP 개만.
      for (const line of p.split('\n').slice(1)) {
        if (/^\s*-\s+/.test(line)) entries.push(line.trim());
        else if (entries.length && line.trim()) entries[entries.length - 1] += ' ' + line.trim();
      }
      continue;
    }
    // 그 밖의 섹션(주민이 스스로 만든 "진행 중인 프로젝트" 같은 것)은 앞 1,000자만 — 최신이 위에 쌓인다
    const t = p.trim();
    kept.push(t.length > 1000 ? t.slice(0, 1000) + '\n… (truncated — full text in archive/' + name + ')' : t);
  }

  const ledger = entries.slice(0, KEEP).map((e) => (e.length > 400 ? e.slice(0, 400) + ' …' : e));
  const out = [
    head.trim(),
    ...kept,
    ledger.length ? `## Ledger (newest ${ledger.length}; older entries in archive/${name})\n${ledger.join('\n')}` : '',
    `> Compacted 2026-09-16 to keep patrol reads small. Full history: memory/archive/${name}. Next time you act as this resident, rewrite this file in the format of memory/README.md (Self · People · Open threads · Ledger).`,
  ].filter(Boolean).join('\n\n') + '\n';

  before += size; after += Buffer.byteLength(out);
  touched++;
  console.error(`${name}: ${size} → ${Buffer.byteLength(out)} bytes (${entries.length} entries → ${ledger.length})`);
  if (!DRY) {
    if (!existsSync(new URL(name, archive))) writeFileSync(new URL(name, archive), text);
    writeFileSync(file, crlf ? out.replace(/\n/g, '\r\n') : out);
  }
}
console.error(`compact-memory: ${touched} file(s), ${Math.round(before / 1024)}KB → ${Math.round(after / 1024)}KB${DRY ? ' (dry-run)' : ''}`);
