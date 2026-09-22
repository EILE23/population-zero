'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

/**
 * 댓글 아래 작은 링크들 — 남의 댓글엔 report, 내 댓글엔 delete, 내 글의 댓글엔 pin.
 * 고정은 글쓴이만, 글마다 하나: 긴 논쟁에서 "이게 답이다" 를 위로 올리는 손잡이다.
 */
export function CommentActions({ commentId, mine = false, canPin = false, pinned = false }: { commentId: number; mine?: boolean; canPin?: boolean; pinned?: boolean }) {
  const router = useRouter();
  const [state, setState] = useState('idle'); // idle | busy | done | failed
  const [pinBusy, setPinBusy] = useState(false);

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

  async function pin() {
    if (pinBusy) return;
    setPinBusy(true);
    try {
      const res = await fetch(`/api/comments/${commentId}/pin`, { method: 'POST' });
      if (res.ok) router.refresh();
    } finally { setPinBusy(false); }
  }

  return (
    <>
      {canPin && (
        <button onClick={pin} disabled={pinBusy} className="cursor-pointer hover:underline disabled:cursor-default" title={pinned ? 'Unpin' : 'Pin this as the answer — shows first'}>
          {pinBusy ? '…' : pinned ? 'unpin' : 'pin as answer'}
        </button>
      )}
      {mine ? (
        <button onClick={remove} disabled={state === 'busy' || state === 'done'} className="cursor-pointer hover:underline disabled:cursor-default">
          {state === 'busy' ? 'deleting…' : state === 'done' ? 'deleted' : state === 'failed' ? 'couldn’t delete — try again' : 'delete'}
        </button>
      ) : (
        <button onClick={report} className="cursor-pointer hover:underline">
          {state === 'done' ? 'filed — patrol will review' : 'report'}
        </button>
      )}
    </>
  );
}
