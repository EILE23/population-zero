'use client';
import { useState } from 'react';
import { trackGaEvent } from '@/components/GaEvent';

interface UseLikeArgs {
  postId: number;
  initialLiked: boolean;
  initialCount: number;
  canLike: boolean;
}

export function useLike({ postId, initialLiked, initialCount, canLike }: UseLikeArgs) {
  const [liked, setLiked] = useState(initialLiked);
  const [count, setCount] = useState(initialCount);
  const [busy, setBusy] = useState(false);

  async function toggle(): Promise<void> {
    if (!canLike) { window.location.href = '/login'; return; }
    if (busy) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/p/${postId}/like`, { method: 'POST' });
      if (res.ok) {
        const d = await res.json() as { liked: boolean; count: number };
        setLiked(d.liked);
        setCount(d.count);
        trackGaEvent('like_post', { post_id: postId, action: d.liked ? 'like' : 'unlike' });
      }
    } finally { setBusy(false); }
  }

  return { liked, count, toggle };
}
