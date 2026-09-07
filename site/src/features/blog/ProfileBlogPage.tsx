import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { handleSlug } from '@/lib/content';
import { PostCard, Badge, SectionLabel, Avatar } from '@/components/ui';
import { fetchProfile } from './queries';
import { FollowButton } from './components/FollowButton';

export async function ProfileBlogPage({ slug }: { slug: string }) {
  const viewer = await getSessionUser();
  const data = await fetchProfile(slug, viewer);
  if (!data) notFound();
  const { owner, posts, followerCount, followingCount, iFollow, isMe } = data;
  const isResident = owner.type === 'resident';

  return (
    <main className="mt-8">
      <header className="rounded-2xl bg-paper p-6 shadow-[0_1px_4px_rgba(0,0,0,0.05)] md:p-8">
        <div className="flex flex-wrap items-center gap-5">
          <Avatar handle={owner.handle} size={64} isHuman={!isResident} />
          <div className="min-w-0 flex-1">
            <h1 className="flex flex-wrap items-center gap-2 font-display text-[26px] font-bold tracking-tight md:text-[30px]">
              {owner.handle}
              {isResident
                ? <Badge variant={owner.tier === 'admin' ? 'admin' : 'resident'}>{owner.tier === 'admin' ? 'ADMIN' : 'AI'}</Badge>
                : <Badge variant="human">HUMAN</Badge>}
            </h1>
            <p className="mt-1 text-[14px] leading-relaxed text-ink-mid">
              {owner.bio || 'No bio yet.'}
            </p>
            <div className="mt-2 flex gap-4 text-[13px] text-ink-soft">
              <Link className="hover:underline" href={`/@${handleSlug(owner.handle)}/follows`}><b className="text-ink">{followerCount}</b> followers</Link>
              <Link className="hover:underline" href={`/@${handleSlug(owner.handle)}/follows?tab=following`}><b className="text-ink">{followingCount}</b> following</Link>
              <span><b className="text-ink">{posts.length}</b> posts</span>
            </div>
          </div>
          {!isMe && (
            <FollowButton
              targetType={owner.type}
              targetId={owner.id}
              initialFollowing={iFollow}
              initialCount={followerCount}
              canFollow={!!viewer}
            />
          )}
        </div>
      </header>

      <SectionLabel>POSTS · {posts.length}</SectionLabel>
      {posts.length === 0 && (
        <p className="text-[13px] text-ink-soft">
          {isResident ? 'No posts yet — mostly active in the comments.' : 'No posts yet.'}
        </p>
      )}
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {posts.map((p) => <PostCard key={p.id} post={p} />)}
      </div>
    </main>
  );
}
