import Link from 'next/link';
import { timeAgo, profileHref } from '@/lib/content';
import { SectionLabel, Avatar } from '@/components/ui';
import { CommentActions } from '../components/CommentActions';
import { ReplyForm } from '../components/ReplyForm';
import { EditableCommentBody } from '../components/EditableCommentBody';
import type { CommentView } from '../types';

function CommentItem({ c, postId, canReply, viewerId, isReply = false }: { c: CommentView; postId: number; canReply: boolean; viewerId: number | null; isReply?: boolean }) {
  if (c.hidden) {
    return <div className="py-3 text-[13px] italic text-ink-soft">[ removed by moderators ]</div>;
  }
  const name = c.resident_id != null ? c.resident_handle : c.user_handle;
  const display = name ?? c.visitor_name ?? 'visitor';
  return (
    <div className="flex gap-3 py-3.5">
      <Avatar handle={display} size={isReply ? 28 : 34} isHuman={c.resident_id == null} src={c.user_avatar} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
          {name
            ? <Link className="text-[13.5px] font-bold hover:underline hover:underline-offset-2" href={profileHref(name)}>{name}</Link>
            : <span className="text-[13.5px] font-bold">{display}</span>}
          <span className="text-[11.5px] text-ink-soft">{timeAgo(c.created_at)}{c.edited_at ? ' · (edited)' : ''}</span>
        </div>
        {viewerId != null && c.user_id === viewerId
          ? <EditableCommentBody commentId={c.id} initialBody={c.body} />
          : <div className="mt-1 whitespace-pre-wrap wrap-break-word text-[15px] leading-relaxed">{c.body}</div>}
        <div className="mt-1.5 flex items-center gap-3 text-[11px] text-ink-soft">
          {canReply && !isReply && <ReplyForm postId={postId} parentId={c.id} />}
          <CommentActions commentId={c.id} />
        </div>
      </div>
    </div>
  );
}

export function CommentsSection({ comments, postId, canReply, viewerId = null }: { comments: CommentView[]; postId: number; canReply: boolean; viewerId?: number | null }) {
  const visible = comments.filter((c) => !c.hidden);
  const topLevel = comments.filter((c) => c.parent_id == null);
  // 대댓글의 대댓글(3단 이상)이 있으면 화면에서 사라진다 — 최상위 아래로 전부 평탄화해 시간순 한 단계로 표시
  const descendantsOf = (rootId: number) => {
    const out: CommentView[] = [];
    let frontier = new Set([rootId]);
    while (frontier.size) {
      const next = comments.filter((c) => c.parent_id != null && frontier.has(c.parent_id));
      out.push(...next);
      frontier = new Set(next.map((c) => c.id));
    }
    return out.sort((a, b) => (a.created_at < b.created_at ? -1 : 1));
  };
  return (
    <>
      <SectionLabel>COMMENTS · {visible.length}</SectionLabel>
      {visible.length === 0 && <p className="py-2 text-[13px] text-ink-soft">No comments yet.</p>}
      {topLevel.map((c) => (
        <div className="border-t border-hairline" key={c.id}>
          <CommentItem c={c} postId={postId} canReply={canReply} viewerId={viewerId} />
          {descendantsOf(c.id).map((r) => (
            <div className="ml-5 border-l-2 border-hairline pl-4" key={r.id}>
              <CommentItem c={r} postId={postId} canReply={canReply} viewerId={viewerId} isReply />
            </div>
          ))}
        </div>
      ))}
    </>
  );
}
