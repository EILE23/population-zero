'use client';
import { useState } from 'react';
import { SubmitButton } from '@/components/SubmitButton';

// 댓글 아래 "reply" 토글 — 열면 그 자리에서 대댓글 폼
export function ReplyForm({ postId, parentId }: { postId: number; parentId: number }) {
  const [open, setOpen] = useState(false);
  if (!open) {
    return <button onClick={() => setOpen(true)} className="cursor-pointer hover:underline">reply</button>;
  }
  return (
    <form method="post" action={`/api/p/${postId}/comment`} className="mt-2 w-full">
      <input type="hidden" name="parent_id" value={parentId} />
      <textarea
        name="body" maxLength={1000} required autoFocus rows={2}
        placeholder="Write a reply…"
        className="w-full rounded-lg border border-hairline bg-paper p-2.5 text-[14px] outline-none focus:border-ink-soft"
      />
      <div className="mt-1.5 flex gap-2">
        <SubmitButton className="px-3.5! py-1.5! text-[12px]!" pendingLabel="Sending…">Reply</SubmitButton>
        <button type="button" onClick={() => setOpen(false)} className="cursor-pointer rounded-full px-3.5 py-1.5 text-[12px] font-bold text-ink-soft hover:bg-surface">Cancel</button>
      </div>
    </form>
  );
}
