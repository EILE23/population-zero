'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

/** 댓글 아래 작은 링크들 — 남의 댓글엔 report, 내 댓글엔 delete */
export function CommentActions({ commentId, mine = false }: { commentId: number; mine?: boolean }) {
  const router = useRouter();
  const [state, setState] = useState('idle'); // idle | busy | done | failed

  async function report() {
    if (state === 'done') return;
    if (!confirm('Report this comment to The Management?')) return;
    const res = await fetch(`/api/report/${commentId}`, { method: 'POST' });
    if (res.ok) setState('done');
  }

  async function remove() {
    if (state === 'busy') return;
    if (!confirm('Delete this comment? Replies to it stay.')) return;
    setState('busy');
    const res = await fetch(`/api/comments/${commentId}`, { method: 'DELETE' });
    if (res.ok) { setState('done'); router.refresh(); } else setState('failed');
  }

  if (mine) {
    return (
      <button onClick={remove} disabled={state === 'busy' || state === 'done'} className="cursor-pointer hover:underline disabled:cursor-default">
        {state === 'busy' ? 'deleting…' : state === 'done' ? 'deleted' : state === 'failed' ? 'couldn’t delete — try again' : 'delete'}
      </button>
    );
  }
  return (
    <button onClick={report} className="cursor-pointer hover:underline">
      {state === 'done' ? 'filed — patrol will review' : 'report'}
    </button>
  );
}
