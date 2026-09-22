'use client';
import { useState } from 'react';
import { trackGaEvent } from '@/components/GaEvent';
import { rememberHere } from '@/components/LoginLink';
import type { ProfileKind } from '../types';

/**
 * 팔로우 — 눌러서 넣고 다시 눌러 뺀다. 로그아웃이면 가입으로 보내되 이 자리로 돌아오게 한다(pz_next).
 * compact: 글 끝·목록처럼 좁은 자리용 작은 알약.
 */
export function FollowButton({ targetType, targetId, initialFollowing, initialCount, canFollow, compact = false }: {
  targetType: ProfileKind;
  targetId: number;
  initialFollowing: boolean;
  initialCount: number;
  canFollow: boolean;
  compact?: boolean;
}) {
  const [following, setFollowing] = useState(initialFollowing);
  const [count, setCount] = useState(initialCount);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function toggle(): Promise<void> {
    if (!canFollow) { rememberHere(); window.location.href = '/login?mode=signup'; return; }
    if (busy) return;
    setBusy(true); setError('');
    try {
      const res = await fetch('/api/follow', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ target_type: targetType, target_id: targetId }),
      });
      if (!res.ok) throw new Error();
      const d = await res.json() as { following: boolean; count: number };
      setFollowing(d.following);
      setCount(d.count);
      trackGaEvent('follow', { target_type: targetType, target_id: targetId, action: d.following ? 'follow' : 'unfollow' });
    } catch { setError('Could not save that. Try again.'); }
    finally { setBusy(false); }
  }

  const size = compact ? 'px-3.5 py-1.5 text-[12.5px]' : 'px-5 py-2 text-sm';
  return (
    <span className="inline-flex flex-col items-start gap-1">
      <button
        onClick={toggle}
        aria-pressed={following}
        title={following ? 'Stop following' : 'New posts from this blog in your feed'}
        className={`cursor-pointer rounded-full font-bold transition-opacity hover:opacity-85 ${size} ${following ? 'bg-surface text-ink' : 'bg-ink text-paper'}`}
      >
        {following ? 'Following' : 'Follow'} · {count}
      </button>
      {error && <span role="alert" className="text-[11.5px] text-accent-deep">{error}</span>}
    </span>
  );
}
