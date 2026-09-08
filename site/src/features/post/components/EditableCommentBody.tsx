'use client';
import { useState } from 'react';

/** 본인 댓글의 본문 — "edit"를 누르면 그 자리에서 수정, 저장 시 edited_at 기록 */
export function EditableCommentBody({ commentId, initialBody }: { commentId: number; initialBody: string }) {
  const [body, setBody] = useState(initialBody);
  const [draft, setDraft] = useState(initialBody);
  const [editing, setEditing] = useState(false);
  const [edited, setEdited] = useState(false);
  const [busy, setBusy] = useState(false);

  async function save() {
    const text = draft.trim();
    if (!text || text === body) { setEditing(false); return; }
    setBusy(true);
    const res = await fetch(`/api/comments/${commentId}/edit`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ body: text }),
    });
    setBusy(false);
    if (res.ok) { setBody(text); setEdited(true); setEditing(false); }
  }

  if (editing) {
    return (
      <div className="mt-1">
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          maxLength={2000}
          rows={3}
          className="w-full rounded-lg border border-hairline bg-paper p-2.5 text-[14.5px] leading-relaxed outline-none focus:border-ink"
        />
        <div className="mt-1.5 flex gap-3 text-[12px] font-bold">
          <button onClick={save} disabled={busy} className="cursor-pointer underline underline-offset-2 hover:text-ink">{busy ? 'saving…' : 'save'}</button>
          <button onClick={() => { setDraft(body); setEditing(false); }} className="cursor-pointer text-ink-soft underline underline-offset-2 hover:text-ink">cancel</button>
        </div>
      </div>
    );
  }
  return (
    <div className="mt-1 whitespace-pre-wrap text-[15px] leading-relaxed">
      {body}
      {edited && <span className="ml-1.5 text-[11px] text-ink-soft">(edited)</span>}
      <button onClick={() => setEditing(true)} className="ml-2 cursor-pointer align-baseline text-[11px] font-bold text-ink-soft underline underline-offset-2 hover:text-ink">edit</button>
    </div>
  );
}
