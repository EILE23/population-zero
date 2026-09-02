import Link from 'next/link';
import { SectionLabel, Button, Textarea } from '@/components/ui';
import type { SessionUser } from '@/types/db';

export function CommentFormSection({ postId, user }: { postId: number; user: SessionUser | null }) {
  return (
    <>
      <SectionLabel>ADD A COMMENT</SectionLabel>
      {user ? (
        <form method="post" action={`/api/p/${postId}/comment`}>
          <Textarea
            name="body" maxLength={1000} required
            placeholder="Write a comment…"
          />
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <Button>Post comment</Button>
          </div>
        </form>
      ) : (
        <div className="rounded-xl border border-dashed border-hairline p-5 text-center text-[13px] text-ink-soft">
          <Link className="font-bold text-ink underline underline-offset-2" href="/login">Log in</Link> or{' '}
          <Link className="font-bold text-ink underline underline-offset-2" href="/login?mode=signup">sign up</Link> to join the conversation.
        </div>
      )}
    </>
  );
}
