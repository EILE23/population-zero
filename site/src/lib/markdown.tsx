// 안전한 마크다운 서브셋 렌더러 — dangerouslySetInnerHTML 없이 React 노드만 생성 (XSS 원천 차단).
// 지원: # ## ###, **굵게**, *기울임*, `코드`, ``` 코드블록, > 인용, -/1. 리스트, [텍스트](https://), ![alt](https://이미지), 유튜브 URL 단독 줄 → 임베드
import type { ReactNode } from 'react';

const YT = /^https:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})\S*$/;

function inline(text: string, keyBase: string): ReactNode[] {
  const out: ReactNode[] = [];
  // 이미지 → 링크 → 코드 → 굵게 → 기울임 순서로 토큰화
  const re = /(!\[([^\]]*)\]\((https:\/\/[^\s)]+)\))|(\[([^\]]+)\]\((https:\/\/[^\s)]+)\))|(`([^`]+)`)|(\*\*([^*]+)\*\*)|(\*([^*]+)\*)/g;
  let last = 0; let m: RegExpExecArray | null; let i = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(text.slice(last, m.index));
    const k = `${keyBase}-${i++}`;
    if (m[1]) out.push(<img key={k} src={m[3]} alt={m[2]} className="my-2 max-w-full rounded-lg" loading="lazy" />);
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
  let list: { ordered: boolean; items: string[] } | null = null;
  let code: string[] | null = null;
  let quote: string[] = [];
  let key = 0;

  const flushPara = () => { if (para.length) { blocks.push(<p key={key++} className="my-3 leading-[1.8]">{inline(para.join('\n'), `p${key}`).map((n, j) => typeof n === 'string' ? n.split('\n').flatMap((s, x) => x ? [<br key={`b${key}-${j}-${x}`} />, s] : [s]) : n)}</p>); para = []; } };
  const flushList = () => { if (list) { const L = list.ordered ? 'ol' : 'ul'; blocks.push(<L key={key++} className={`my-3 pl-6 leading-[1.8] ${list.ordered ? 'list-decimal' : 'list-disc'}`}>{list.items.map((it, j) => <li key={j} className="my-1">{inline(it, `l${key}-${j}`)}</li>)}</L>); list = null; } };
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
    const h = line.match(/^(#{1,3})\s+(.+)$/);
    if (h) { flushAll(); const size = ['text-[24px]', 'text-[20px]', 'text-[17px]'][h[1].length - 1]; blocks.push(<div key={key++} role="heading" aria-level={h[1].length + 1} className={`mb-2 mt-6 font-display font-bold tracking-tight ${size}`}>{inline(h[2], `h${key}`)}</div>); continue; }
    const yt = line.trim().match(YT);
    if (yt) { flushAll(); blocks.push(<div key={key++} className="relative my-4 aspect-video w-full overflow-hidden rounded-xl bg-surface"><iframe className="absolute inset-0 h-full w-full border-0" src={`https://www.youtube-nocookie.com/embed/${yt[1]}`} title="video" loading="lazy" allowFullScreen /></div>); continue; }
    if (line.startsWith('> ')) { flushPara(); flushList(); quote.push(line.slice(2)); continue; }
    const ul = line.match(/^[-*]\s+(.+)$/);
    const ol = line.match(/^\d+[.)]\s+(.+)$/);
    if (ul || ol) {
      flushPara(); flushQuote();
      const ordered = !!ol;
      if (!list || list.ordered !== ordered) { flushList(); list = { ordered, items: [] }; }
      list.items.push((ul ?? ol)![1]);
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
    .replace(/^[-*]\s+/gm, '')
    .replace(/[*`]/g, '');
}
