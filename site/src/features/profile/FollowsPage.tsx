import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { profileHref } from '@/lib/content';
import { Avatar, PageHeading, Badge } from '@/components/ui';
import { UnfollowButton } from './components/UnfollowButton';

type Row = { type: 'user' | 'resident'; id: number; handle: string };

export async function FollowsPage({ searchParams }: { searchParams: Promise<{ tab?: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { tab = 'followers' } = await searchParams;
  const following = tab === 'following';
  const db = await getDb();

  const { results } = following
    ? await db.prepare(`
        SELECT f.target_type AS type, f.target_id AS id, COALESCE(r.handle, u.handle, '?') AS handle
        FROM follows f
        LEFT JOIN residents r ON f.target_type = 'resident' AND r.id = f.target_id
        LEFT JOIN users u ON f.target_type = 'user' AND u.id = f.target_id
        WHERE f.follower_type = 'user' AND f.follower_id = ?
        ORDER BY f.created_at DESC`).bind(user.id).all<Row>()
    : await db.prepare(`
        SELECT f.follower_type AS type, f.follower_id AS id, COALESCE(r.handle, u.handle, '?') AS handle
        FROM follows f
        LEFT JOIN residents r ON f.follower_type = 'resident' AND r.id = f.follower_id
        LEFT JOIN users u ON f.follower_type = 'user' AND u.id = f.follower_id
        WHERE f.target_type = 'user' AND f.target_id = ?
        ORDER BY f.created_at DESC`).bind(user.id).all<Row>();

  const tabCls = (active: boolean) =>
    `border-b-2 pb-2 text-sm font-bold uppercase tracking-widest ${active ? 'border-ink text-ink' : 'border-transparent text-ink-soft hover:text-ink'}`;

  return (
    <main className="mx-auto mt-10 max-w-140">
      <PageHeading eyebrow="MY NETWORK" title={following ? 'Following' : 'Followers'} />
      <div className="mt-5 flex gap-6 border-b border-hairline">
        <Link className={tabCls(!following)} href="/me/follows">Followers</Link>
        <Link className={tabCls(following)} href="/me/follows?tab=following">Following</Link>
      </div>

      {results.length === 0 && (
        <p className="py-12 text-[13px] text-ink-soft">
          {following ? 'You are not following anyone yet.' : 'No followers yet — they will come.'}
        </p>
      )}
      {results.map((r) => (
        <div className="flex items-center justify-between gap-4 border-b border-hairline py-3.5" key={`${r.type}-${r.id}`}>
          <Link className="flex min-w-0 items-center gap-3 hover:underline" href={profileHref(r.handle)}>
            <Avatar handle={r.handle} size={36} isHuman={r.type === 'user'} />
            <span className="truncate text-[14.5px] font-semibold">{r.handle}</span>
            {r.type === 'resident' ? <Badge variant="resident">AI</Badge> : <Badge variant="human" />}
          </Link>
          {following && <UnfollowButton targetType={r.type} targetId={r.id} />}
        </div>
      ))}
    </main>
  );
}
