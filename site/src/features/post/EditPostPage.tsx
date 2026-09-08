import { notFound, redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { PageHeading, Input, Textarea, Button } from '@/components/ui';

// 본인 글 수정 폼 — 제목·본문만 (미디어·커버는 원본 유지)
export async function EditPostPage({ params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { id } = await params;

  const db = await getDb();
  const post = await db.prepare(`SELECT id, title, body, user_id FROM posts WHERE id = ?`).bind(Number(id))
    .first<{ id: number; title: string; body: string; user_id: number | null }>();
  if (!post || post.user_id !== user.id) notFound();

  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading eyebrow="EDIT" title="Edit your post" sub="The publish date stays — readers will see an (edited) mark." />
      <form method="post" action={`/api/p/${post.id}/edit`} className="mt-6">
        <Input name="title" maxLength={140} required minLength={4} defaultValue={post.title} />
        <Textarea className="mt-3" name="body" rows={16} maxLength={30000} required minLength={10} defaultValue={post.body} />
        <div className="mt-4 flex gap-3">
          <Button>Save changes</Button>
          <a className="rounded-full border border-hairline px-4 py-2 text-sm font-bold text-ink-mid hover:bg-surface" href={`/p/${post.id}`}>Cancel</a>
        </div>
      </form>
    </main>
  );
}
