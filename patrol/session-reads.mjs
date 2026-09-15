// 세션이 실제로 무엇을 읽었나 — claude -p 의 stream-json 출력에서 도구 호출과 결과 크기를 뽑아 한 장으로.
// 토큰 다이어트의 근거는 "합계 30만" 이 아니라 "무엇이 30만인가" 다. 이 파일이 없으면 줄일 곳을 짐작으로 고른다.
// 사용: node session-reads.mjs logs/session.jsonl  →  logs/session-reads.json (record-run 이 상위 항목을 run-log 에 싣는다)
import { readFileSync, writeFileSync } from 'node:fs';

const src = process.argv[2] ?? 'logs/session.jsonl';
let lines = [];
try { lines = readFileSync(src, 'utf8').split('\n').filter(Boolean); } catch { console.error('session-reads: no session log'); process.exit(0); }

const calls = new Map(); // tool_use id → { tool, target }
const reads = [];        // { tool, target, chars }
let turns = 0, toolCalls = 0;
for (const line of lines) {
  let ev; try { ev = JSON.parse(line); } catch { continue; }
  const blocks = ev?.message?.content;
  if (!Array.isArray(blocks)) continue;
  if (ev.type === 'assistant') turns++;
  for (const b of blocks) {
    if (b.type === 'tool_use') {
      toolCalls++;
      const i = b.input ?? {};
      const target = i.file_path ?? i.path ?? i.command ?? i.pattern ?? i.query ?? i.url ?? '';
      calls.set(b.id, { tool: b.name, target: String(target).slice(0, 160) });
    } else if (b.type === 'tool_result') {
      const c = calls.get(b.tool_use_id) ?? { tool: '?', target: '' };
      const text = typeof b.content === 'string' ? b.content : (b.content ?? []).map((x) => x.text ?? '').join('');
      reads.push({ ...c, chars: text.length });
    }
  }
}
reads.sort((a, b) => b.chars - a.chars);
const total = reads.reduce((s, r) => s + r.chars, 0);
const byTool = {};
for (const r of reads) byTool[r.tool] = (byTool[r.tool] ?? 0) + r.chars;
const summary = { turns, toolCalls, resultChars: total, approxTokens: Math.round(total / 4), byTool, top: reads.slice(0, 15) };
writeFileSync(src.replace(/[^/\\]+$/, 'session-reads.json'), JSON.stringify(summary, null, 2));
console.error(`session-reads: ${toolCalls} tool calls, ${Math.round(total / 1000)}k chars of results (~${summary.approxTokens} tokens)`);
for (const r of reads.slice(0, 10)) console.error(`  ${String(r.chars).padStart(7)}  ${r.tool}  ${r.target}`);
