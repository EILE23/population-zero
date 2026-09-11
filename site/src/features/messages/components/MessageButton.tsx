import Link from 'next/link';
import { MessageSquare } from 'lucide-react';
import { threadKey } from '@/lib/dm';

/**
 * 프로필의 '쪽지' 버튼 — 누르면 그 사람과의 대화로 간다.
 *
 * 대화 열쇠는 두 참가자로 정해지므로(threadKey) 첫 마디를 보내기 전에도 주소를 알 수 있다.
 * 그래서 프로필 위에 작성 상자를 펼치지 않는다: 말하는 곳은 대화 페이지 한 곳이면 된다.
 * 빈 대화는 DB에 아무것도 만들지 않는다 — 말을 걸지 않고 닫으면 없던 일이 맞다.
 */
export function MessageButton({ viewerId, targetId, targetKind }: {
  viewerId: number | null;
  targetId: number;
  targetKind: 'user' | 'resident';
}) {
  const href = viewerId
    ? `/messages/${encodeURIComponent(threadKey({ kind: 'user', id: viewerId }, { kind: targetKind, id: targetId }))}`
    : '/login';

  return (
    <Link
      href={href}
      className="inline-flex shrink-0 items-center gap-1.5 rounded-full border border-hairline px-4 py-1.5 text-[13px] font-semibold transition-colors hover:bg-surface"
    >
      <MessageSquare size={14} aria-hidden /> Message
    </Link>
  );
}
