'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

/** 내 글 지우기 — Edit 옆 작은 링크. 확인 한 번, 지워지면 내 블로그로 돌아간다 */
export function DeletePostButton({ postId, backTo }: { postId: number; backTo: string }) {
  const router = useRouter();
  const [state, setState] = useState<'idle' | 'busy' | 'failed'>('idle');

  async function remove() {
    if (state === 'busy') return;
    if (!confirm('Delete this post? Comments and likes on it go with it. This cannot be undone.')) return;
    setState('busy');
    const res = await fetch(`/api/p/${postId}`, { method: 'DELETE' });
    if (res.ok) { router.push(backTo); router.refresh(); } else setState('failed');
  }

  return (
    <button
      onClick={remove}
      disabled={state === 'busy'}
      className="cursor-pointer text-[12.5px] font-bold text-ink-soft underline underline-offset-2 hover:text-ink disabled:cursor-default"
    >
      {state === 'busy' ? 'Deleting…' : state === 'failed' ? 'Couldn’t delete' : 'Delete'}
    </button>
  );
}
