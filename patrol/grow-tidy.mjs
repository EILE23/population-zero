// 성장 문서 순환 — 회차 시작 때 돌린다(grow-code.yml). 발전은 계속되고 문서는 짧게 유지된다.
//   GROW-BACKLOG.md : 완료([x]) 항목을 빼서 GROW-DONE.md 로 옮긴다(날짜와 함께). 열린 항목만 남는다. 항목이 하나도 없는 섹션 제목은 지운다.
//   GROW-LOG.md     : 400줄을 넘으면 앞부분(오래된 것)을 growth/YYYY-MM.md 로 말아 둔다. 최근 200줄만 남긴다.
//   GAMES-LOG.md    : 같은 규칙.
// 실행: node grow-tidy.mjs   (레포 어디서든; 파일은 이 파일 기준 상대 경로)
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const here = (p) => new URL(p, import.meta.url);
const today = new Date().toISOString().slice(0, 10);
const month = today.slice(0, 7);
const read = (p) => (existsSync(here(p)) ? readFileSync(here(p), 'utf8').replace(/\r\n/g, '\n') : '');
const write = (p, s) => writeFileSync(here(p), s.replace(/\n{3,}/g, '\n\n').trimEnd() + '\n');

// ── 백로그: 완료 항목 → GROW-DONE.md ──
{
  const lines = read('./GROW-BACKLOG.md').split('\n');
  const keep = [], done = [];
  let section = '';
  for (const l of lines) {
    if (/^## /.test(l)) { section = l.replace(/^## /, ''); keep.push(l); continue; }
    if (/^- \[x\]/i.test(l)) { done.push(`- ${today} · ${section ? `${section} · ` : ''}${l.replace(/^- \[x\]\s*/i, '')}`); continue; }
    keep.push(l);
  }
  // 마을의 소원은 순찰마다 하나씩 쌓인다 — 열린 소원은 최근 10건만 남기고 나머지는 DONE 에 '(expired wish)' 로 보낸다(백로그가 소원으로 부풀지 않게)
  { const wishIdx = keep.map((l, i) => (/^- \[ \] \(town wish/.test(l) ? i : -1)).filter((i) => i >= 0); const drop = new Set(wishIdx.slice(0, Math.max(0, wishIdx.length - 10)));
    for (const i of drop) { done.push(`- ${today} · expired wish · ${keep[i].replace(/^- \[ \]\s*/, '')}`); keep[i] = null; }
    for (let i = keep.length - 1; i >= 0; i--) if (keep[i] === null) keep.splice(i, 1); }
  // 열린 항목이 하나도 없는 섹션 제목은 지운다(제목 다음에 다른 제목이나 파일 끝이 오면)
  const out = [];
  for (let i = 0; i < keep.length; i++) {
    if (/^## /.test(keep[i])) {
      let j = i + 1; let has = false;
      while (j < keep.length && !/^## /.test(keep[j])) { if (/^- \[ \]/.test(keep[j])) has = true; j++; }
      if (!has) { i = j - 1; continue; }
    }
    out.push(keep[i]);
  }
  if (done.length) {
    const prev = read('./GROW-DONE.md') || '# Square growth — done items (moved out of the backlog by grow-tidy.mjs; the log has the how)\n';
    write('./GROW-DONE.md', prev.trimEnd() + '\n' + done.join('\n') + '\n');
    write('./GROW-BACKLOG.md', out.join('\n'));
    console.log(`backlog: moved ${done.length} done item(s) to GROW-DONE.md`);
  } else console.log('backlog: nothing to move');
}

// ── 로그: 길면 월별로 말아 둔다 ──
for (const name of ['GROW-LOG.md', 'GAMES-LOG.md']) {
  const text = read(`./${name}`); if (!text) continue;
  const lines = text.split('\n');
  if (lines.length <= 400) { console.log(`${name}: ${lines.length} lines, fine`); continue; }
  const head = lines.slice(0, 2).join('\n'); // 제목 줄과 빈 줄
  const body = lines.slice(2);
  const old = body.slice(0, body.length - 200), recent = body.slice(-200);
  mkdirSync(here('./growth/'), { recursive: true });
  const arch = `./growth/${name.replace('.md', '')}-${month}.md`;
  write(arch, (read(arch) || `# ${name} archive ${month}\n`).trimEnd() + '\n' + old.join('\n') + '\n');
  write(`./${name}`, head + '\n' + recent.join('\n'));
  console.log(`${name}: rolled ${old.length} lines into ${arch}`);
}
