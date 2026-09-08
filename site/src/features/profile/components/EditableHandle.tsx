'use client';
import { useState } from 'react';
import { Pencil, Check } from 'lucide-react';

/** 마이페이지 이름 — 클릭하면 입력으로 바뀌고 엔터/버튼으로 저장 (블로그 제목과 같은 UX) */
export function EditableHandle({ initialHandle }: { initialHandle: string }) {
  const [handle, setHandle] = useState(initialHandle);
  const [draft, setDraft] = useState(initialHandle);
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    const next = draft.trim();
    if (busy) return;
    if (!next || next === handle) { setEditing(false); setError(null); return; }
    if (!/^[A-Za-z0-9_-]{3,20}$/.test(next)) { setError('3–20 chars: letters, numbers, - or _'); return; }
    setBusy(true);
    setError(null);
    try {
      const res = await fetch('/api/me/handle', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ handle: next }),
      });
      if (res.ok) {
        setHandle(next);
        setEditing(false);
        location.reload(); // 헤더·블로그 링크 등 세션 표시 전부 갱신
      } else {
        const d = (await res.json().catch(() => ({}))) as { error?: string };
        setError(d.error === 'taken' ? 'Already taken — try another.' : d.error === 'rate' ? 'Too many attempts. Wait a bit.' : 'Invalid handle.');
      }
    } finally { setBusy(false); }
  }

  if (editing) {
    return (
      <div>
        <div className="flex items-center gap-2">
          <input
            autoFocus
            value={draft}
            maxLength={20}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') save(); if (e.key === 'Escape') { setDraft(handle); setEditing(false); setError(null); } }}
            className="w-full max-w-70 border-0 border-b-2 border-ink bg-transparent font-display text-[30px] font-bold tracking-tight outline-none"
          />
          <button onClick={save} disabled={busy} aria-label="Save handle"
            className="shrink-0 cursor-pointer rounded-full bg-ink p-2 text-paper hover:opacity-85 disabled:opacity-40">
            <Check size={16} strokeWidth={2.6} />
          </button>
        </div>
        <p className="mt-1 text-[11.5px] text-ink-soft">{error ?? 'Changing your handle also changes your blog address.'}</p>
      </div>
    );
  }
  return (
    <button
      onClick={() => { setDraft(handle); setEditing(true); }}
      title="Click to change your handle"
      className="group flex cursor-pointer items-center gap-2 text-left font-display text-[30px] font-bold tracking-tight"
    >
      {handle}
      <Pencil size={17} strokeWidth={2.2} className="text-ink-faint opacity-0 transition-opacity group-hover:opacity-100" />
    </button>
  );
}
