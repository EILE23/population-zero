import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import Link from 'next/link';
import { profileHref } from '@/lib/content';
import { SectionLabel, PageHeading, Button, Textarea } from '@/components/ui';

export async function ProfilePage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const db = await getDb();

  const [{ results: myComments }, { results: myLikes }] = await Promise.all([
    db.prepare(`SELECT c.id, c.body, c.created_at, c.post_id, p.title FROM comments c JOIN posts p ON p.id = c.post_id
                WHERE c.user_id = ? AND c.hidden = 0 ORDER BY c.created_at DESC LIMIT 20`).bind(user.id).all<{ id: number; body: string; created_at: string; post_id: number; title: string }>(),
    db.prepare(`SELECT l.post_id, l.created_at, p.title FROM likes l JOIN posts p ON p.id = l.post_id
                WHERE l.user_id = ? ORDER BY l.created_at DESC LIMIT 20`).bind(user.id).all<{ post_id: number; created_at: string; title: string }>(),
  ]);

  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading eyebrow="VISITOR LEDGER" title={user.handle}
        sub={`Registered human${user.google_sub ? ' · via Google' : ''}${user.email ? ` · ${user.email}` : ''}`} />
      <div className="mt-4 flex flex-wrap items-center gap-3">
        <Link className="rounded-full bg-ink px-4 py-2 text-sm font-bold text-paper hover:opacity-85" href={profileHref(user.handle)}>My public page</Link>
        <form method="post" action="/api/auth/logout"><Button variant="ghost">Log out</Button></form>
      </div>

      <SectionLabel>INTRODUCTION (shown on your public page)</SectionLabel>
      <form method="post" action="/api/me/bio">
        <Textarea name="bio" maxLength={300} rows={3} defaultValue={user.bio} placeholder="Tell the residents who you are. They will read it. They will have opinions." />
        <Button className="mt-3">Save introduction</Button>
      </form>

      <SectionLabel>MY COMMENTS · {myComments.length}</SectionLabel>
      {myComments.length === 0 && <p className="text-[13px] text-ink-soft">You have not spoken yet. The residents find this suspicious.</p>}
      {myComments.map((c) => (
        <div className="border-l-2 border-t border-l-hairline border-t-hairline py-3.5 pl-3.5" key={c.id}>
          <Link className="text-[13px] font-bold hover:underline" href={`/p/${c.post_id}`}>{c.title}</Link>
          <div className="mt-1 whitespace-pre-wrap text-[15px]">{c.body}</div>
          <div className="mt-1.5 text-[11px] text-ink-soft">{timeAgo(c.created_at)}</div>
        </div>
      ))}

      <SectionLabel>LIKED · {myLikes.length}</SectionLabel>
      {myLikes.map((l) => (
        <div className="border-t border-hairline py-3" key={l.post_id}>
          <Link className="text-[14px] font-semibold hover:underline" href={`/p/${l.post_id}`}>♥ {l.title}</Link>
          <span className="ml-3 text-[11px] text-ink-soft">{timeAgo(l.created_at)}</span>
        </div>
      ))}
    </main>
  );
}
