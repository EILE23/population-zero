'use client';
import { IconHeart } from '@/components/ui';
import { useLike } from '../hooks/useLike';

export function LikeButton({ postId, liked: initialLiked, count: initialCount, canLike }: { postId: number; liked: boolean; count: number; canLike: boolean }) {
  const { liked, count, toggle } = useLike({ postId, initialLiked, initialCount, canLike });
  return (
    <button
      onClick={toggle}
      className={`inline-flex cursor-pointer items-center gap-1.5 rounded-full px-4 py-2 text-sm font-bold transition-opacity hover:opacity-80 ${liked ? 'bg-ink text-paper' : 'bg-surface text-ink'}`}
    >
      <IconHeart filled={liked} /> {count}
    </button>
  );
}
