// 안전한 마크다운 서브셋 렌더러 — dangerouslySetInnerHTML 없이 React 노드만 생성 (XSS 원천 차단).
// 지원: # ## ###, **굵게**, *기울임*, `코드`, ``` 코드블록, > 인용, -/1. 리스트, [텍스트](https://), ![alt](https://이미지), 유튜브 URL 단독 줄 → 임베드
import type { ReactNode } from 'react';

const YT = /^https:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})\S*$/;

/** 헤딩 텍스트 → 앵커 id. 목차 링크와 본문 헤딩이 같은 규칙을 써야 점프가 맞는다. */
function headingId(text: string, index: number): string {
  const base = String(text)
    .replace(/[*`_[\]()]/g, '')
    .trim().toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^\p{L}\p{N}-]/gu, '')
    .slice(0, 50);
  return `h-${index}${base ? '-' + base : ''}`; // index 를 앞에 둬 제목이 겹쳐도 중복되지 않는다
}

export type Heading = { level: number; text: string; id: string };

/** 본문에서 목차용 헤딩 목록을 뽑는다 (코드블록 안의 # 는 제외). */
export function extractHeadings(text: string): Heading[] {
  const out: Heading[] = [];
  let inCode = false;
  let i = 0;
  for (const raw of String(text).split('\n')) {
    const line = raw.replace(/\s+$/, '');
    if (line.trim().startsWith('```')) { inCode = !inCode; continue; }
    if (inCode) continue;
    const m = line.match(/^(#{1,3})\s+(.+)$/);
    if (!m) continue;
    const clean = m[2].replace(/[*`]/g, '').trim();
    out.push({ level: m[1].length, text: clean, id: headingId(clean, i) });
    i++;
  }
  return out;
}

function inline(text: string, keyBase: string): ReactNode[] {
  const out: ReactNode[] = [];
  // 이미지 → 링크 → 코드 → 굵게 → 기울임 순서로 토큰화
  const re = /(!\[([^\]]*)\]\((https:\/\/[^\s)]+)\))|(\[([^\]]+)\]\((https:\/\/[^\s)]+)\))|(`([^`]+)`)|(\*\*([^*]+)\*\*)|(\*([^*]+)\*)/g;
  let last = 0; let m: RegExpExecArray | null; let i = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(text.slice(last, m.index));
    const k = `${keyBase}-${i++}`;
    // referrerPolicy: 외부 이미지는 글쓴이가 지정한 서버에서 방문자 브라우저가 직접 받는다.
    // 어느 글을 보고 있는지까지 넘기지 않도록 리퍼러를 끊는다 (IP·UA 는 요청 특성상 남는다).
    if (m[1]) out.push(<img key={k} src={m[3]} alt={m[2]} className="my-2 max-w-full rounded-lg" loading="lazy" referrerPolicy="no-referrer" />);
    else if (m[4]) out.push(<a key={k} href={m[6]} target="_blank" rel="noopener nofollow" className="underline underline-offset-2">{m[5]}</a>);
    else if (m[7]) out.push(<code key={k} className="rounded bg-surface-deep px-1.5 py-0.5 font-mono text-[0.9em]">{m[8]}</code>);
    else if (m[9]) out.push(<strong key={k}>{m[10]}</strong>);
    else if (m[11]) out.push(<em key={k}>{m[12]}</em>);
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

export function Markdown({ text }: { text: string }) {
  const lines = String(text).split('\n');
  const blocks: ReactNode[] = [];
  let para: string[] = [];
  // 중첩 목록 — 들여쓰기 2칸마다 한 단계. 탭은 2칸으로 환산한다.
  type ListNode = { ordered: boolean; depth: number; items: { text: string; children: ListNode | null }[] };
  let list: ListNode | null = null;
  let code: string[] | null = null;
  let quote: string[] = [];
  let key = 0;
  let headingIdx = 0; // extractHeadings 와 같은 순번 — 목차 링크가 이 id 로 점프한다

  const flushPara = () => { if (para.length) { blocks.push(<p key={key++} className="my-3 leading-[1.8]">{inline(para.join('\n'), `p${key}`).map((n, j) => typeof n === 'string' ? n.split('\n').flatMap((s, x) => x ? [<br key={`b${key}-${j}-${x}`} />, s] : [s]) : n)}</p>); para = []; } };
  const renderList = (node: ListNode, k: string): ReactNode => {
    const L = node.ordered ? 'ol' : 'ul';
    return (
      <L key={k} className={`my-3 pl-6 leading-[1.8] ${node.ordered ? 'list-decimal' : 'list-disc'}`}>
        {node.items.map((it, j) => (
          <li key={j} className="my-1">
            {inline(it.text, `${k}-${j}`)}
            {it.children && renderList(it.children, `${k}-${j}-c`)}
          </li>
        ))}
      </L>
    );
  };
  const flushList = () => { if (list) { blocks.push(renderList(list, `l${key++}`)); list = null; } };
  const flushQuote = () => { if (quote.length) { blocks.push(<blockquote key={key++} className="my-3 border-l-2 border-ink pl-4 text-ink-mid">{inline(quote.join('\n'), `q${key}`)}</blockquote>); quote = []; } };
  const flushAll = () => { flushPara(); flushList(); flushQuote(); };

  for (const raw of lines) {
    const line = raw.replace(/\s+$/, '');
    if (code !== null) {
      if (line.trim() === '```') { blocks.push(<pre key={key++} className="my-3 overflow-x-auto rounded-lg bg-ink p-4 font-mono text-[13px] leading-relaxed text-paper"><code>{code.join('\n')}</code></pre>); code = null; }
      else code.push(raw);
      continue;
    }
    if (line.trim().startsWith('```')) { flushAll(); code = []; continue; }
    const h = line.match(/^(#{1,3})(?:\s+(.*))?$/);
    if (h) {
      flushAll();
      const size = ['text-[24px]', 'text-[20px]', 'text-[17px]'][h[1].length - 1];
      const clean = (h[2] ?? '').replace(/[*`]/g, '').trim();
      // 목차(extractHeadings)와 같은 순번·규칙으로 id 를 매겨야 클릭 시 정확히 이 헤딩으로 점프한다.
      // scroll-mt: 스크롤 시 헤딩이 화면 맨 위에 딱 붙지 않게 여백을 둔다
      blocks.push(
        <div key={key++} id={headingId(clean, headingIdx++)} role="heading" aria-level={h[1].length + 1}
          className={`mb-2 mt-6 scroll-mt-20 font-display font-bold tracking-tight ${size}`}>
          {inline(h[2] ?? '', `h${key}`)}
        </div>,
      );
      continue;
    }
    const yt = line.trim().match(YT);
    if (yt) { flushAll(); blocks.push(<div key={key++} className="relative my-4 aspect-video w-full overflow-hidden rounded-xl bg-surface"><iframe className="absolute inset-0 h-full w-full border-0" src={`https://www.youtube-nocookie.com/embed/${yt[1]}`} title="video" loading="lazy" allowFullScreen /></div>); continue; }
    if (line.startsWith('> ')) { flushPara(); flushList(); quote.push(line.slice(2)); continue; }
    // 들여쓴 목록도 받는다: "  - 중첩", "\t- 중첩" (탭=2칸). depth 는 2칸당 1단계.
    const li = line.match(/^([ \t]*)(?:[-*]|(\d+)[.)])\s+(.*)$/);
    if (li) {
      flushPara(); flushQuote();
      const depth = Math.floor(li[1].replace(/\t/g, '  ').length / 2);
      const ordered = li[2] !== undefined;
      const text = li[3] ?? '';
      if (!list) list = { ordered, depth: 0, items: [] };
      // depth 만큼 내려가며 자식 목록을 찾거나 만든다
      let node = list;
      for (let d = 0; d < depth; d++) {
        const last = node.items[node.items.length - 1];
        if (!last) break; // 부모 없이 들여쓰기부터 시작한 경우 — 현재 단계에 그대로 붙인다
        if (!last.children) last.children = { ordered, depth: d + 1, items: [] };
        node = last.children;
      }
      node.items.push({ text, children: null });
      continue;
    }
    if (line.trim() === '') { flushAll(); continue; }
    flushList(); flushQuote();
    para.push(line);
  }
  flushAll();
  if (code !== null) blocks.push(<pre key={key++} className="my-3 overflow-x-auto rounded-lg bg-ink p-4 font-mono text-[13px] text-paper"><code>{code.join('\n')}</code></pre>);
  return <div className="wrap-break-word text-[16px]">{blocks}</div>;
}

/** 피드 발췌용 — 마크다운 기호 제거 */
export function stripMarkdown(text: string): string {
  return String(text)
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/^#{1,3}\s+/gm, '')
    .replace(/^>\s?/gm, '')
    .replace(/^\s*[-*]\s+/gm, '')
    .replace(/[*`]/g, '');
}
