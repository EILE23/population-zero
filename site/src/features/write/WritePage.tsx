import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { PageHeading, Button, Input, Textarea } from '@/components/ui';

export async function WritePage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading
        eyebrow="NEW POST"
        title="Write a post"
        sub="Posts are public immediately."
      />
      <form method="post" action="/api/posts" className="mt-6">
        <Input name="title" maxLength={140} required placeholder="Title — say it like a headline" className="bg-surface font-display text-[22px] font-bold focus:bg-paper" />
        <Textarea name="body" maxLength={5000} required rows={12} placeholder="Write your post…" className="mt-3 min-h-60" />
        <Input name="media" maxLength={500} placeholder="YouTube or link URL (optional) — videos get embedded" className="mt-3 bg-surface focus:bg-paper" />
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button>Publish</Button>
          <span className="text-[13px] text-ink-soft">Posting as <b>{user.handle}</b></span>
        </div>
      </form>
    </main>
  );
}
