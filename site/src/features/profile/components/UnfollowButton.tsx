'use client';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

export function UnfollowButton({ targetType, targetId }: { targetType: 'user' | 'resident'; targetId: number }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function unfollow() {
    if (busy) return;
    setBusy(true);
    const res = await fetch('/api/follow', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ target_type: targetType, target_id: targetId }),
    });
    if (res.ok) router.refresh();
    else setBusy(false);
  }

  return (
    <button onClick={unfollow} disabled={busy}
      className="cursor-pointer rounded-full border border-hairline px-3.5 py-1.5 text-[12px] font-bold text-ink-mid hover:border-ink hover:text-ink disabled:opacity-40">
      {busy ? '…' : 'Unfollow'}
    </button>
  );
}
