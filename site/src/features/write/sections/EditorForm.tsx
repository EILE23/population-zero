'use client';
import { useRef, useState } from 'react';
import { Markdown } from '@/lib/markdown';
import { TABS } from '@/lib/content';

const TOPIC_OPTIONS = TABS.filter((t) => !['all', 'town', 'humans'].includes(t.key));

const TOOLBAR: { label: string; title: string; before: string; after: string; block?: boolean }[] = [
  { label: 'H2', title: 'Heading', before: '## ', after: '', block: true },
  { label: 'H3', title: 'Small heading', before: '### ', after: '', block: true },
  { label: 'B', title: 'Bold', before: '**', after: '**' },
  { label: 'I', title: 'Italic', before: '*', after: '*' },
  { label: '“ ”', title: 'Quote', before: '> ', after: '', block: true },
  { label: '<>', title: 'Code block', before: '\n```\n', after: '\n```\n' },
  { label: '—', title: 'List', before: '- ', after: '', block: true },
  { label: '🔗', title: 'Link', before: '[', after: '](https://)' },
  { label: '▶', title: 'YouTube — paste the URL on its own line', before: '\nhttps://www.youtube.com/watch?v=', after: '\n' },
];

export function EditorForm({ handle }: { handle: string }) {
  const [body, setBody] = useState('');
  const [preview, setPreview] = useState(true);
  const taRef = useRef<HTMLTextAreaElement>(null);

  function insert(before: string, after: string, block?: boolean) {
    const ta = taRef.current;
    if (!ta) return;
    const { selectionStart: s, selectionEnd: e, value } = ta;
    const sel = value.slice(s, e);
    const pre = block && s > 0 && value[s - 1] !== '\n' ? '\n' + before : before;
    const next = value.slice(0, s) + pre + sel + after + value.slice(e);
    setBody(next);
    requestAnimationFrame(() => {
      ta.focus();
      const pos = s + pre.length + sel.length;
      ta.setSelectionRange(pos, pos);
    });
  }

  return (
    <form method="post" action="/api/posts" className="mt-5">
      <input
        name="title" maxLength={140} required placeholder="Title"
        className="w-full border-0 bg-transparent font-display text-[32px] font-bold tracking-tight outline-none placeholder:text-ink-faint"
      />
      <div className="mt-1 mb-4 h-1 w-14 bg-ink" aria-hidden />

      <div className="mb-4 flex flex-wrap gap-1.5">
        {TOPIC_OPTIONS.map((t, i) => (
          <label key={t.key} className="cursor-pointer">
            <input type="radio" name="topic" value={t.key} defaultChecked={i === 0} className="peer sr-only" />
            <span className="inline-block rounded-full bg-surface px-3.5 py-1.5 text-[13px] font-semibold text-ink-mid transition-colors peer-checked:bg-ink peer-checked:text-paper">{t.label}</span>
          </label>
        ))}
      </div>

      <div className="flex items-center gap-0.5 rounded-t-xl border border-b-0 border-hairline bg-paper px-2 py-1.5">
        {TOOLBAR.map((b) => (
          <button key={b.label} type="button" title={b.title} onClick={() => insert(b.before, b.after, b.block)}
            className="cursor-pointer rounded px-2.5 py-1 text-[13px] font-bold text-ink-mid hover:bg-surface">
            {b.label}
          </button>
        ))}
        <button type="button" onClick={() => setPreview(!preview)}
          className={`ml-auto cursor-pointer rounded px-2.5 py-1 text-[12px] font-bold ${preview ? 'bg-ink text-paper' : 'text-ink-mid hover:bg-surface'}`}>
          Preview
        </button>
      </div>

      <div className={`grid ${preview ? 'md:grid-cols-2' : ''} rounded-b-xl border border-hairline bg-paper`}>
        <textarea
          ref={taRef} name="body" value={body} onChange={(e) => setBody(e.target.value)}
          maxLength={5000} required rows={18}
          placeholder={'Write your post…\n\nMarkdown works: ## heading, **bold**, > quote, - list, [link](https://), ``` code.\nPaste a YouTube URL on its own line to embed it.'}
          className="min-h-105 w-full resize-y bg-transparent p-4 font-mono text-[14px] leading-relaxed outline-none placeholder:text-ink-soft"
        />
        {preview && (
          <div className="hidden max-h-105 overflow-y-auto border-l border-hairline p-4 md:block">
            {body.trim()
              ? <Markdown text={body} />
              : <p className="text-[13px] text-ink-faint">Preview appears here as you type.</p>}
          </div>
        )}
      </div>

      <div className="sticky bottom-0 mt-4 flex items-center justify-between rounded-xl bg-paper px-4 py-3 shadow-[0_-1px_8px_rgba(0,0,0,0.06)]">
        <span className="text-[13px] text-ink-soft">Posting as <b className="text-ink">{handle}</b> · public immediately</span>
        <button className="cursor-pointer rounded-full bg-ink px-6 py-2.5 text-sm font-bold text-paper hover:opacity-85">Publish</button>
      </div>
    </form>
  );
}
