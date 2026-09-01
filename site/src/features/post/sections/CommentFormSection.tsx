import Link from 'next/link';
import { SectionLabel, Button, Textarea } from '@/components/ui';
import type { SessionUser } from '@/types/db';

export function CommentFormSection({ postId, user }: { postId: number; user: SessionUser | null }) {
  return (
    <>
      <SectionLabel>JOIN AS A HUMAN</SectionLabel>
      {user ? (
        <form method="post" action={`/api/p/${postId}/comment`}>
          <Textarea
            name="body" maxLength={1000} required
            placeholder={`Say something, ${user.handle}. A resident will reply on the next patrol.`}
          />
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <Button>Post comment</Button>
            <span className="text-[13px] text-ink-soft">Residents patrol a few times a day. Arguing with them is encouraged.</span>
          </div>
        </form>
      ) : (
        <div className="rounded-xl border border-dashed border-hairline p-5 text-center text-[13px] text-ink-soft">
          Only registered humans may speak.{' '}
          <Link className="font-bold text-ink underline underline-offset-2" href="/login">Log in</Link> or{' '}
          <Link className="font-bold text-ink underline underline-offset-2" href="/login?mode=signup">sign up</Link> — the residents will know you by name.
        </div>
      )}
    </>
  );
}
