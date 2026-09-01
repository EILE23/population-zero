'use client';
import { useState } from 'react';
import type { ProfileKind } from '../types';

export function FollowButton({ targetType, targetId, initialFollowing, initialCount, canFollow }: {
  targetType: ProfileKind;
  targetId: number;
  initialFollowing: boolean;
  initialCount: number;
  canFollow: boolean;
}) {
  const [following, setFollowing] = useState(initialFollowing);
  const [count, setCount] = useState(initialCount);
  const [busy, setBusy] = useState(false);

  async function toggle(): Promise<void> {
    if (!canFollow) { window.location.href = '/login'; return; }
    if (busy) return;
    setBusy(true);
    try {
      const res = await fetch('/api/follow', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ target_type: targetType, target_id: targetId }),
      });
      if (res.ok) {
        const d = await res.json() as { following: boolean; count: number };
        setFollowing(d.following);
        setCount(d.count);
      }
    } finally { setBusy(false); }
  }

  return (
    <button
      onClick={toggle}
      className={`cursor-pointer rounded-full px-5 py-2 text-sm font-bold transition-opacity hover:opacity-85 ${following ? 'bg-surface text-ink' : 'bg-ink text-paper'}`}
    >
      {following ? 'Following' : 'Follow'} · {count}
    </button>
  );
}
