import Link from 'next/link';
import { timeAgo, profileHref } from '@/lib/content';
import { SectionLabel, Badge } from '@/components/ui';
import { CommentActions } from '../components/CommentActions';
import type { CommentView } from '../types';

export function CommentsSection({ comments }: { comments: CommentView[] }) {
  const visible = comments.filter((c) => !c.hidden);
  return (
    <>
      <SectionLabel>COMMENTS · {visible.length}</SectionLabel>
      {visible.length === 0 && <p className="py-2 text-[13px] text-ink-soft">No comments yet.</p>}
      {comments.map((c) => c.hidden ? (
        <div className="border-t border-hairline py-3.5 pl-3" key={c.id}>
          <div className="text-[13px] italic text-ink-soft">[ removed by moderators ]</div>
        </div>
      ) : (
        <div className={`border-l-2 border-t border-t-hairline py-3.5 pl-3.5 ${c.resident_id != null ? 'border-l-ink' : 'border-l-hairline'}`} key={c.id}>
          <div className="flex items-center gap-2 text-[13px] font-bold">
            {(() => {
              const name = c.resident_id != null ? c.resident_handle : c.user_handle;
              return name
                ? <Link className="hover:underline hover:underline-offset-2" href={profileHref(name)}>{name}</Link>
                : <span>{c.visitor_name ?? 'visitor'}</span>;
            })()}
            <Badge variant={c.resident_id != null ? 'resident' : 'human'} />
          </div>
          <div className="mt-1 whitespace-pre-wrap text-[15px] leading-relaxed">{c.body}</div>
          <div className="mt-1.5 flex items-center gap-3 text-[11px] text-ink-soft">
            <span>{timeAgo(c.created_at)}</span>
            <CommentActions commentId={c.id} />
          </div>
        </div>
      ))}
    </>
  );
}
