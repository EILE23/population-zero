// 안전한 마크다운 렌더러 — dangerouslySetInnerHTML 없이 React 노드만 생성 (XSS 원천 차단).
// 무엇을 어떻게 읽을지는 lib/markdown-ast.ts(웹·앱 공용 파서)가 정하고, 여기서는 그 블록을 HTML 로 그린다.
import type { ReactNode } from 'react';
import { parseMarkdown, parseInline, type Block, type ListBlock } from './markdown-ast';

export { extractHeadings, stripMarkdown, type Heading } from './markdown-ast';

function inline(text: string, keyBase: string): ReactNode[] {
  return parseInline(text).map((tok, i) => {
    const k = `${keyBase}-${i}`;
    switch (tok.t) {
      // referrerPolicy: 외부 이미지는 글쓴이가 지정한 서버에서 방문자 브라우저가 직접 받는다.
      // 어느 글을 보고 있는지까지 넘기지 않도록 리퍼러를 끊는다 (IP·UA 는 요청 특성상 남는다).
      case 'img': return <img key={k} src={tok.src} alt={tok.alt} className="my-2 max-w-full rounded-lg" loading="lazy" referrerPolicy="no-referrer" />;
      case 'link': return <a key={k} href={tok.href} target="_blank" rel="noopener nofollow" className="underline underline-offset-2">{tok.text}</a>;
      case 'code': return <code key={k} className="rounded bg-surface-deep px-1.5 py-0.5 font-mono text-[0.9em]">{tok.v}</code>;
      case 'strong': return <strong key={k}>{tok.v}</strong>;
      case 'em': return <em key={k}>{tok.v}</em>;
      default: return tok.v;
    }
  });
}

/** 문단 안의 한 줄바꿈은 <br> — 주민 글은 레딧처럼 짧은 줄을 잇는다 */
function withBreaks(nodes: ReactNode[], keyBase: string): ReactNode[] {
  return nodes.flatMap<ReactNode>((n, j) => typeof n === 'string'
    ? n.split('\n').flatMap<ReactNode>((s, x) => x ? [<br key={`${keyBase}-b${j}-${x}`} />, s] : [s])
    : [n]);
}

function renderList(node: ListBlock, k: string): ReactNode {
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
}

function renderBlock(b: Block, key: number): ReactNode {
  const k = `b${key}`;
  switch (b.type) {
    case 'heading': {
      const size = ['text-[24px]', 'text-[20px]', 'text-[17px]'][b.level - 1];
      // scroll-mt: 스크롤 시 헤딩이 화면 맨 위에 딱 붙지 않게 여백을 둔다. id 는 목차(extractHeadings)와 같은 규칙.
      return (
        <div key={k} id={b.id} role="heading" aria-level={Math.max(2, b.level)} className={`mb-2 mt-6 scroll-mt-20 font-display font-bold tracking-tight ${size}`}>
          {inline(b.text, k)}
        </div>
      );
    }
    case 'paragraph': return <p key={k} className="my-3 leading-[1.8]">{withBreaks(inline(b.text, k), k)}</p>;
    case 'list': return renderList(b, k);
    case 'code': return <pre key={k} className="my-3 overflow-x-auto rounded-lg bg-ink p-4 font-mono text-[13px] leading-relaxed text-paper"><code>{b.text}</code></pre>;
    case 'quote': return <blockquote key={k} className="my-3 border-l-2 border-ink pl-4 text-ink-mid">{withBreaks(inline(b.text, k), k)}</blockquote>;
    case 'youtube': return (
      <div key={k} className="relative my-4 aspect-video w-full overflow-hidden rounded-xl bg-surface">
        <iframe className="absolute inset-0 h-full w-full border-0" src={`https://www.youtube-nocookie.com/embed/${b.id}`} title="video" loading="lazy" allowFullScreen />
      </div>
    );
  }
}

export function Markdown({ text }: { text: string }) {
  return <div className="wrap-break-word text-[16px]">{parseMarkdown(text).map(renderBlock)}</div>;
}
