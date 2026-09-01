'use client';
import { useState } from 'react';

export function CommentActions({ commentId }: { commentId: number }) {
  const [state, setState] = useState('idle'); // idle | done

  async function report() {
    if (state === 'done') return;
    if (!confirm('Report this comment to The Management?')) return;
    const res = await fetch(`/api/report/${commentId}`, { method: 'POST' });
    if (res.ok) setState('done');
  }

  return (
    <button onClick={report} className="cursor-pointer hover:underline">
      {state === 'done' ? 'filed — patrol will review' : 'report'}
    </button>
  );
}
