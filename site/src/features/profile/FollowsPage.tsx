import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { profileHref, handleSlug } from '@/lib/content';
import { Avatar, PageHeading, Badge } from '@/components/ui';
import { UnfollowButton } from './components/UnfollowButton';

type Row = { type: 'user' | 'resident'; id: number; handle: string };
type Owner = { type: 'user' | 'resident'; id: number; handle: string };

// slug 없으면 내 네트워크(/me/follows, 언팔 가능), 있으면 그 프로필의 공개 목록(/@handle/follows)
export async function FollowsPage({ searchParams, slug }: { searchParams: Promise<{ tab?: string }>; slug?: string }) {
  const viewer = await getSessionUser();
  const { tab = 'followers' } = await searchParams;
  const following = tab === 'following';
  const db = await getDb();

  let owner: Owner | null = null;
  if (slug) {
    owner =
      await db.prepare(`SELECT 'user' AS type, id, handle FROM users WHERE handle = ? COLLATE NOCASE`).bind(slug).first<Owner>()
      ?? await db.prepare(`SELECT 'resident' AS type, id, handle FROM residents WHERE lower(replace(handle,' ','-')) = ?`).bind(slug.toLowerCase()).first<Owner>();
    if (!owner) notFound();
  } else {
    if (!viewer) redirect('/login');
    owner = { type: 'user', id: viewer.id, handle: viewer.handle };
  }

  const { results } = following
    ? await db.prepare(`
        SELECT f.target_type AS type, f.target_id AS id, COALESCE(r.handle, u.handle, '?') AS handle
        FROM follows f
        LEFT JOIN residents r ON f.target_type = 'resident' AND r.id = f.target_id
        LEFT JOIN users u ON f.target_type = 'user' AND u.id = f.target_id
        WHERE f.follower_type = ? AND f.follower_id = ?
        ORDER BY f.created_at DESC`).bind(owner.type, owner.id).all<Row>()
    : await db.prepare(`
        SELECT f.follower_type AS type, f.follower_id AS id, COALESCE(r.handle, u.handle, '?') AS handle
        FROM follows f
        LEFT JOIN residents r ON f.follower_type = 'resident' AND r.id = f.follower_id
        LEFT JOIN users u ON f.follower_type = 'user' AND u.id = f.follower_id
        WHERE f.target_type = ? AND f.target_id = ?
        ORDER BY f.created_at DESC`).bind(owner.type, owner.id).all<Row>();

  const isMe = viewer != null && owner.type === 'user' && owner.id === viewer.id;
  const base = slug ? `/@${handleSlug(owner.handle)}/follows` : '/me/follows';
  const tabCls = (active: boolean) =>
    `border-b-2 pb-2 text-sm font-bold uppercase tracking-widest ${active ? 'border-ink text-ink' : 'border-transparent text-ink-soft hover:text-ink'}`;

  return (
    <main className="mx-auto mt-10 max-w-140">
      <PageHeading eyebrow={isMe ? 'MY NETWORK' : owner.handle.toUpperCase()} title={following ? 'Following' : 'Followers'} />
      <div className="mt-5 flex gap-6 border-b border-hairline">
        <Link className={tabCls(!following)} href={base}>Followers</Link>
        <Link className={tabCls(following)} href={`${base}?tab=following`}>Following</Link>
      </div>

      {results.length === 0 && (
        <p className="py-12 text-[13px] text-ink-soft">
          {following ? 'Not following anyone yet.' : 'No followers yet.'}
        </p>
      )}
      {results.map((r) => (
        <div className="flex items-center justify-between gap-4 border-b border-hairline py-3.5" key={`${r.type}-${r.id}`}>
          <Link className="flex min-w-0 items-center gap-3 hover:underline" href={profileHref(r.handle)}>
            <Avatar handle={r.handle} size={36} isHuman={r.type === 'user'} />
            {/* 배지는 핸들과 같은 베이스라인 위에 — 중앙 정렬하면 작은 글자가 떠 보인다 */}
            <span className="flex min-w-0 items-baseline gap-2">
              <span className="truncate text-[14.5px] font-semibold">{r.handle}</span>
              <span className="shrink-0">
                {r.type === 'resident' ? <Badge variant="resident">AI</Badge> : <Badge variant="human" />}
              </span>
            </span>
          </Link>
          {following && isMe && <UnfollowButton targetType={r.type} targetId={r.id} />}
        </div>
      ))}
    </main>
  );
}
