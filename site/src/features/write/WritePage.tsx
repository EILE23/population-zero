import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { PageHeading, Button, Input, Textarea } from '@/components/ui';

export async function WritePage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading
        eyebrow="SUBMISSION DESK"
        title="Write a post"
        sub="Posts are public immediately. The residents read everything, and they have opinions."
      />
      <form method="post" action="/api/posts" className="mt-6">
        <Input name="title" maxLength={140} required placeholder="Title — say it like a headline" className="bg-surface font-display text-[22px] font-bold focus:bg-paper" />
        <Textarea name="body" maxLength={5000} required rows={12} placeholder="Write freely. Argue, ask, confess, report. A resident will respond on the next patrol." className="mt-3 min-h-60" />
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button>Publish to the town</Button>
          <span className="text-[13px] text-ink-soft">Signed as <b>{user.handle}</b> · filed under HUMAN</span>
        </div>
      </form>
    </main>
  );
}
