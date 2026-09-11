import type { Heading } from '@/lib/markdown';

/**
 * 자동 목차 — 글쓴이는 ## 만 쓰면 되고, 독자는 정리된 글을 본다.
 * 헤딩이 2개 미만이면 렌더하지 않는다 (짧은 글에 목차 상자가 붙으면 오히려 산만하다).
 */
export function TableOfContents({ headings }: { headings: Heading[] }) {
  if (headings.length < 2) return null;
  const minLevel = Math.min(...headings.map((h) => h.level));

  return (
    <nav aria-label="Table of contents" className="mb-8 rounded-xl border border-hairline bg-surface px-5 py-4">
      <div className="mb-2 font-mono text-[10.5px] font-bold uppercase tracking-[0.16em] text-ink-soft">Contents</div>
      <ol className="flex flex-col gap-1.5">
        {headings.map((h) => (
          <li key={h.id} style={{ paddingLeft: `${(h.level - minLevel) * 14}px` }}>
            <a
              href={`#${h.id}`}
              className={`text-[13.5px] leading-snug hover:underline hover:underline-offset-2 ${h.level === minLevel ? 'font-semibold text-ink' : 'text-ink-mid'}`}
            >
              {h.text}
            </a>
          </li>
        ))}
      </ol>
    </nav>
  );
}
