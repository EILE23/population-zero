import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import Link from 'next/link';
import { profileHref } from '@/lib/content';
import { SectionLabel, Button, Textarea, Counts } from '@/components/ui';
import { AvatarUpload } from './components/AvatarUpload';
import { EditableHandle } from './components/EditableHandle';

type MyPost = { id: number; title: string; created_at: string; comment_count: number; like_count: number };
type MyComment = { id: number; body: string; created_at: string; post_id: number; title: string };
type MyLike = { post_id: number; created_at: string; title: string };

function Stat({ n, label, href }: { n: number; label: string; href?: string }) {
  const inner = (
    <>
      <div className="font-display text-[22px] font-bold tabular-nums">{n}</div>
      <div className="mt-0.5 font-mono text-[10px] uppercase tracking-[0.1em] text-ink-soft">{label}</div>
    </>
  );
  const cls = 'min-w-16 rounded-xl bg-paper px-4 py-3 text-center shadow-[0_1px_4px_rgba(0,0,0,0.05)]';
  return href
    ? <Link href={href} className={`${cls} block transition-shadow hover:shadow-[0_2px_8px_rgba(0,0,0,0.1)]`}>{inner}</Link>
    : <div className={cls}>{inner}</div>;
}

export async function ProfilePage({ searchParams }: { searchParams?: Promise<{ verified?: string; sent?: string; error?: string; welcome?: string }> } = {}) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { verified, sent, error, welcome } = (await searchParams) ?? {};
  const db = await getDb();

  const [{ results: myPosts }, { results: myComments }, { results: myLikes }, stats, joined] = await Promise.all([
    db.prepare(`SELECT p.id, p.title, p.created_at,
                  (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count,
                  (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id)
                    + (SELECT COUNT(*) FROM resident_likes rl WHERE rl.post_id = p.id AND rl.created_at <= datetime('now')) AS like_count
                FROM posts p WHERE p.user_id = ? ORDER BY p.created_at DESC LIMIT 15`).bind(user.id).all<MyPost>(),
    db.prepare(`SELECT c.id, c.body, c.created_at, c.post_id, p.title FROM comments c JOIN posts p ON p.id = c.post_id
                WHERE c.user_id = ? AND c.hidden = 0 ORDER BY c.created_at DESC LIMIT 15`).bind(user.id).all<MyComment>(),
    db.prepare(`SELECT l.post_id, l.created_at, p.title FROM likes l JOIN posts p ON p.id = l.post_id
                WHERE l.user_id = ? ORDER BY l.created_at DESC LIMIT 15`).bind(user.id).all<MyLike>(),
    db.prepare(`SELECT
        (SELECT COUNT(*) FROM posts WHERE user_id = ?1) AS posts,
        (SELECT COUNT(*) FROM comments WHERE user_id = ?1 AND hidden = 0) AS comments,
        (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id = l.post_id WHERE p.user_id = ?1)
          + (SELECT COUNT(*) FROM resident_likes rl JOIN posts p ON p.id = rl.post_id WHERE p.user_id = ?1 AND rl.created_at <= datetime('now')) AS likes_received,
        (SELECT COUNT(*) FROM follows WHERE target_type = 'user' AND target_id = ?1) AS followers,
        (SELECT COUNT(*) FROM follows WHERE follower_type = 'user' AND follower_id = ?1) AS following`)
      .bind(user.id).first<{ posts: number; comments: number; likes_received: number; followers: number; following: number }>(),
    db.prepare(`SELECT created_at FROM users WHERE id = ?`).bind(user.id).first<{ created_at: string }>(),
  ]);

  const notice =
    verified ? 'Email verified — you can now post and comment. Welcome aboard.'
    : sent ? 'Verification email sent. Check your inbox (and spam).'
    : welcome ? 'Account created! Check your email for a verification link — posting unlocks after you click it.'
    : error === 'unverified' ? 'Verify your email first — posting and commenting unlock after verification.'
    : error === 'rate' ? 'Too many attempts. Wait a few minutes and try again.'
    : null;

  return (
    <main className="mt-10 max-w-180">
      {notice && (
        <div role="status" className="mb-6 rounded-lg border-l-4 border-ink bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">{notice}</div>
      )}
      {!user.email_verified && (
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-hairline bg-surface p-4">
          <div className="text-[13.5px]">
            <b>Your email isn&apos;t verified yet.</b>
            <span className="text-ink-mid"> Posting and commenting unlock after you click the link we sent{user.email ? ` to ${user.email}` : ''}.</span>
          </div>
          <form method="post" action="/api/auth/resend-verify">
            <Button variant="ghost">Resend email</Button>
          </form>
        </div>
      )}
      <div className="flex flex-wrap items-center gap-5">
        <AvatarUpload handle={user.handle} avatarUrl={user.avatar_url} />
        <div className="min-w-0">
          <EditableHandle initialHandle={user.handle} />
          <p className="mt-0.5 text-[13px] text-ink-soft">
            Member{user.google_sub ? ' · via Google' : ''}{user.email ? ` · ${user.email}` : ''}
            {joined ? ` · joined ${timeAgo(joined.created_at)}` : ''}
          </p>
          <div className="mt-2.5 flex flex-wrap items-center gap-3">
            <Link className="rounded-full bg-ink px-4 py-2 text-sm font-bold text-paper hover:opacity-85" href={profileHref(user.handle)}>My blog</Link>
            <Link className="rounded-full border border-hairline px-4 py-2 text-sm font-bold text-ink-mid hover:bg-surface" href="/write">Write a post</Link>
            <form method="post" action="/api/auth/logout"><Button variant="ghost">Log out</Button></form>
          </div>
        </div>
      </div>

      <div className="mt-6 flex flex-wrap gap-2.5">
        <Stat n={stats?.posts ?? 0} label="posts" />
        <Stat n={stats?.comments ?? 0} label="comments" />
        <Stat n={stats?.likes_received ?? 0} label="likes received" />
        <Stat n={stats?.followers ?? 0} label="followers" href="/me/follows" />
        <Stat n={stats?.following ?? 0} label="following" href="/me/follows?tab=following" />
      </div>

      <SectionLabel>MY BLOG (title &amp; introduction, shown on your blog)</SectionLabel>
      <form method="post" action="/api/me/bio">
        <input
          name="blog_title"
          maxLength={60}
          defaultValue={user.blog_title ?? ''}
          placeholder="Name your blog (optional) — shown as the big masthead title"
          className="mb-2.5 w-full rounded-xl border border-hairline bg-paper px-3.5 py-2.5 text-[15px] font-semibold outline-none focus:border-ink"
        />
        <Textarea name="bio" maxLength={300} rows={3} defaultValue={user.bio} placeholder="Write a short introduction for your profile." />
        <Button className="mt-3">Save</Button>
      </form>

      <SectionLabel>MY POSTS · {stats?.posts ?? 0}</SectionLabel>
      {myPosts.length === 0 && <p className="text-[13px] text-ink-soft">No posts yet — your first post is one click away.</p>}
      {myPosts.map((p) => (
        <div className="flex items-center justify-between gap-4 border-t border-hairline py-3" key={p.id}>
          <div className="min-w-0">
            <Link className="block truncate text-[14px] font-semibold hover:underline" href={`/p/${p.id}`}>{p.title}</Link>
            <span className="text-[11px] text-ink-soft">{timeAgo(p.created_at)}</span>
          </div>
          <Counts likes={p.like_count} comments={p.comment_count} />
        </div>
      ))}

      <SectionLabel>MY COMMENTS · {stats?.comments ?? 0}</SectionLabel>
      {myComments.length === 0 && <p className="text-[13px] text-ink-soft">No comments yet.</p>}
      {myComments.map((c) => (
        <div className="border-l-2 border-t border-l-hairline border-t-hairline py-3.5 pl-3.5" key={c.id}>
          <Link className="text-[13px] font-bold hover:underline" href={`/p/${c.post_id}`}>{c.title}</Link>
          <div className="mt-1 whitespace-pre-wrap text-[15px]">{c.body}</div>
          <div className="mt-1.5 text-[11px] text-ink-soft">{timeAgo(c.created_at)}</div>
        </div>
      ))}

      <SectionLabel>LIKED · {myLikes.length}</SectionLabel>
      {myLikes.length === 0 && <p className="text-[13px] text-ink-soft">Posts you like will appear here.</p>}
      {myLikes.map((l) => (
        <div className="border-t border-hairline py-3" key={l.post_id}>
          <Link className="text-[14px] font-semibold hover:underline" href={`/p/${l.post_id}`}>♥ {l.title}</Link>
          <span className="ml-3 text-[11px] text-ink-soft">{timeAgo(l.created_at)}</span>
        </div>
      ))}
    </main>
  );
}
