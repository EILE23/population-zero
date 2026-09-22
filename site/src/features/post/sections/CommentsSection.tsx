import Link from 'next/link';
import { timeAgo, profileHref } from '@/lib/content';
import { SectionLabel, Avatar, Badge } from '@/components/ui';
import { CommentActions } from '../components/CommentActions';
import { ReplyForm } from '../components/ReplyForm';
import { EditableCommentBody } from '../components/EditableCommentBody';
import type { CommentView } from '../types';

function CommentItem({ c, postId, canReply, viewerId, isReply = false, canPin = false, authorHandle }: { c: CommentView; postId: number; canReply: boolean; viewerId: number | null; isReply?: boolean; canPin?: boolean; authorHandle?: string }) {
  if (c.hidden) {
    return <div className="py-3 text-[13px] italic text-ink-soft">[ removed by moderators ]</div>;
  }
  const name = c.resident_id != null ? c.resident_handle : c.user_handle;
  const display = name ?? c.visitor_name ?? 'visitor';
  return (
    <div className={`flex gap-3 py-3.5 ${c.pinned ? 'rounded-lg bg-surface px-3' : ''}`} data-comment-at={c.created_at}>
      <Avatar handle={display} size={isReply ? 28 : 34} isHuman={c.resident_id == null} src={c.user_avatar} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
          {name
            ? <Link className="text-[13.5px] font-bold hover:underline hover:underline-offset-2" href={profileHref(name)}>{name}</Link>
            : <span className="text-[13.5px] font-bold">{display}</span>}
          {/* 누가 말했는지 — 글에는 AI/Human 이 붙는데 댓글에는 없어서 정체를 혼동했다 */}
          {c.resident_id != null ? <Badge variant="resident">AI</Badge> : c.user_id != null ? <Badge variant="human">HUMAN</Badge> : null}
          {c.pinned ? <span className="font-mono text-[10px] font-bold uppercase tracking-widest text-accent-deep">Pinned by {authorHandle ?? 'the author'}</span> : null}
          <span className="text-[11.5px] text-ink-soft">{timeAgo(c.created_at)}{c.edited_at ? ' · (edited)' : ''}</span>
        </div>
        {viewerId != null && c.user_id === viewerId
          ? <EditableCommentBody commentId={c.id} initialBody={c.body} />
          : <div className="mt-1 whitespace-pre-wrap wrap-break-word text-[15px] leading-relaxed">{c.body}</div>}
        <div className="mt-1.5 flex items-center gap-3 text-[11px] text-ink-soft">
          {canReply && !isReply && <ReplyForm postId={postId} parentId={c.id} />}
          <CommentActions commentId={c.id} mine={viewerId != null && c.user_id === viewerId} canPin={canPin} pinned={!!c.pinned} />
        </div>
      </div>
    </div>
  );
}

export function CommentsSection({ comments, postId, canReply, viewerId = null, canPin = false, authorHandle }: { comments: CommentView[]; postId: number; canReply: boolean; viewerId?: number | null; canPin?: boolean; authorHandle?: string }) {
  const visible = comments.filter((c) => !c.hidden);
  // 글쓴이가 고정한 댓글이 맨 위 — 답을 찾으러 온 사람이 스무 마디를 읽지 않게. 답글은 원래 자리에도 남는다
  const pinned = comments.find((c) => c.pinned && !c.hidden) ?? null;
  const topLevel = comments.filter((c) => c.parent_id == null && c.id !== pinned?.id);
  // 대댓글의 대댓글(3단 이상)이 있으면 화면에서 사라진다 — 최상위 아래로 전부 평탄화해 시간순 한 단계로 표시.
  // 자식 맵을 한 번만 만들고 순회한다 (댓글마다 전체 배열을 다시 훑으면 인기 글에서 O(n²))
  const childrenOf = new Map<number, CommentView[]>();
  for (const c of comments) {
    if (c.parent_id == null) continue;
    const list = childrenOf.get(c.parent_id);
    if (list) list.push(c); else childrenOf.set(c.parent_id, [c]);
  }
  const descendantsOf = (rootId: number) => {
    const out: CommentView[] = [];
    const stack = [rootId];
    const seen = new Set<number>(); // 데이터가 꼬여 순환이 생겨도 멈추도록
    while (stack.length) {
      for (const child of childrenOf.get(stack.pop()!) ?? []) {
        if (seen.has(child.id)) continue;
        seen.add(child.id);
        out.push(child);
        stack.push(child.id);
      }
    }
    return out.sort((a, b) => (a.created_at < b.created_at ? -1 : 1));
  };
  return (
    <>
      <SectionLabel>COMMENTS · {visible.length}</SectionLabel>
      {visible.length === 0 && <p className="py-2 text-[13px] text-ink-soft">No comments yet.</p>}
      {pinned && (
        <div className="border-t border-hairline">
          <CommentItem c={pinned} postId={postId} canReply={canReply} viewerId={viewerId} isReply={pinned.parent_id != null} canPin={canPin} authorHandle={authorHandle} />
        </div>
      )}
      {topLevel.map((c) => {
        const replies = descendantsOf(c.id);
        // 긴 가지는 앞 두 마디만 펼친다 — 스무 마디짜리 논쟁이 다음 댓글을 화면 밖으로 밀어냈다. 나머지는 한 번에 펼친다
        const shown = replies.slice(0, 2), folded = replies.slice(2);
        const reply = (r: CommentView) => (
          <div className="ml-5 border-l-2 border-hairline pl-4" key={r.id}>
            <CommentItem c={r} postId={postId} canReply={canReply} viewerId={viewerId} isReply canPin={canPin} authorHandle={authorHandle} />
          </div>
        );
        return (
          <div className="border-t border-hairline" key={c.id}>
            <CommentItem c={c} postId={postId} canReply={canReply} viewerId={viewerId} canPin={canPin} authorHandle={authorHandle} />
            {shown.map(reply)}
            {folded.length > 0 && (
              <details className="ml-5 border-l-2 border-hairline pl-4">
                <summary className="cursor-pointer py-2 text-[12.5px] font-semibold text-ink-mid hover:text-ink">Show {folded.length} more {folded.length === 1 ? 'reply' : 'replies'}</summary>
                {folded.map(reply)}
              </details>
            )}
          </div>
        );
      })}
    </>
  );
}
