'use client';
import { useState } from 'react';
import { Pencil, Check } from 'lucide-react';

/** 내 블로그 마스트헤드 제목 — 클릭하면 입력으로 바뀌고 엔터/버튼으로 저장 */
export function EditableBlogTitle({ initialTitle, fallback }: { initialTitle: string | null; fallback: string }) {
  const [title, setTitle] = useState(initialTitle);
  const [draft, setDraft] = useState(initialTitle ?? '');
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState(false);
  const shown = title || fallback;

  async function save() {
    if (busy) return;
    setBusy(true);
    try {
      const res = await fetch('/api/me/blog-title', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ title: draft.trim() }),
      });
      if (res.ok) {
        const d = (await res.json()) as { title: string | null };
        setTitle(d.title);
        setEditing(false);
      }
    } finally { setBusy(false); }
  }

  if (editing) {
    return (
      <div className="flex items-center gap-2.5">
        <input
          autoFocus
          value={draft}
          maxLength={60}
          placeholder={fallback}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') save(); if (e.key === 'Escape') { setDraft(title ?? ''); setEditing(false); } }}
          className="w-full max-w-130 border-0 border-b-2 border-ink bg-transparent font-display text-[34px] font-bold leading-tight tracking-tight outline-none placeholder:text-ink-faint md:text-[42px]"
        />
        <button onClick={save} disabled={busy} aria-label="Save blog title"
          className="shrink-0 cursor-pointer rounded-full bg-ink p-2.5 text-paper hover:opacity-85 disabled:opacity-40">
          <Check size={18} strokeWidth={2.6} />
        </button>
      </div>
    );
  }
  return (
    <button
      onClick={() => { setDraft(title ?? ''); setEditing(true); }}
      title="Click to rename your blog"
      className="group flex cursor-pointer items-center gap-2.5 text-left font-display text-[34px] font-bold leading-tight tracking-tight md:text-[42px]"
    >
      {shown}
      <Pencil size={20} strokeWidth={2.2} className="text-ink-faint opacity-0 transition-opacity group-hover:opacity-100" />
    </button>
  );
}
