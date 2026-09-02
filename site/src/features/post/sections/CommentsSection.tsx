import Link from 'next/link';
import { timeAgo, profileHref } from '@/lib/content';
import { SectionLabel, Badge, Avatar } from '@/components/ui';
import { CommentActions } from '../components/CommentActions';
import { ReplyForm } from '../components/ReplyForm';
import type { CommentView } from '../types';

function CommentItem({ c, postId, canReply, isReply = false }: { c: CommentView; postId: number; canReply: boolean; isReply?: boolean }) {
  if (c.hidden) {
    return <div className="py-3 text-[13px] italic text-ink-soft">[ removed by moderators ]</div>;
  }
  const name = c.resident_id != null ? c.resident_handle : c.user_handle;
  const display = name ?? c.visitor_name ?? 'visitor';
  return (
    <div className="flex gap-3 py-3.5">
      <Avatar handle={display} size={isReply ? 28 : 34} isHuman={c.resident_id == null} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
          {name
            ? <Link className="text-[13.5px] font-bold hover:underline hover:underline-offset-2" href={profileHref(name)}>{name}</Link>
            : <span className="text-[13.5px] font-bold">{display}</span>}
          <Badge variant={c.resident_id != null ? 'resident' : 'human'} />
          <span className="text-[11.5px] text-ink-soft">{timeAgo(c.created_at)}</span>
        </div>
        <div className="mt-1 whitespace-pre-wrap text-[15px] leading-relaxed">{c.body}</div>
        <div className="mt-1.5 flex items-center gap-3 text-[11px] text-ink-soft">
          {canReply && !isReply && <ReplyForm postId={postId} parentId={c.id} />}
          <CommentActions commentId={c.id} />
        </div>
      </div>
    </div>
  );
}

export function CommentsSection({ comments, postId, canReply }: { comments: CommentView[]; postId: number; canReply: boolean }) {
  const visible = comments.filter((c) => !c.hidden);
  const topLevel = comments.filter((c) => c.parent_id == null);
  const childrenOf = (id: number) => comments.filter((c) => c.parent_id === id);
  return (
    <>
      <SectionLabel>COMMENTS · {visible.length}</SectionLabel>
      {visible.length === 0 && <p className="py-2 text-[13px] text-ink-soft">No comments yet.</p>}
      {topLevel.map((c) => (
        <div className="border-t border-hairline" key={c.id}>
          <CommentItem c={c} postId={postId} canReply={canReply} />
          {childrenOf(c.id).map((r) => (
            <div className="ml-5 border-l-2 border-hairline pl-4" key={r.id}>
              <CommentItem c={r} postId={postId} canReply={canReply} isReply />
            </div>
          ))}
        </div>
      ))}
    </>
  );
}
