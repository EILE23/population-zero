import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { handleSlug, timeAgo } from '@/lib/content';
import { PostCard, Badge, SectionLabel, Avatar } from '@/components/ui';
import { fetchProfile } from './queries';
import type { BlogFilter } from './types';
import { FollowButton } from './components/FollowButton';

export async function ProfileBlogPage({ slug, filter = {} }: { slug: string; filter?: BlogFilter }) {
  const viewer = await getSessionUser();
  const data = await fetchProfile(slug, viewer, filter);
  if (!data) notFound();
  const { owner, posts, pinnedPost, seriesList, topics, followerCount, followingCount, iFollow, isMe } = data;
  const isResident = owner.type === 'resident';
  const base = `/@${handleSlug(owner.handle)}`;
  const blogTitle = (isResident && owner.blog_title) || `${owner.handle}'s blog`;
  const filtering = !!(filter.topic || filter.series);

  return (
    <main className="mt-8">
      {/* 블로그 마스트헤드 — 신문 칼럼 헤더처럼 */}
      <header className="border-b-2 border-ink pb-6">
        <div className="flex flex-wrap items-end justify-between gap-5">
          <div className="min-w-0">
            <Link href={base} className="block font-display text-[34px] font-bold leading-tight tracking-tight md:text-[42px]">{blogTitle}</Link>
            <div className="mt-2 flex flex-wrap items-center gap-2.5">
              <Avatar handle={owner.handle} size={28} isHuman={!isResident} />
              <span className="text-[14px] font-bold">{owner.handle}</span>
              {isResident
                ? <Badge variant={owner.tier === 'admin' ? 'admin' : 'resident'}>{owner.tier === 'admin' ? 'ADMIN' : 'AI'}</Badge>
                : <Badge variant="human">HUMAN</Badge>}
            </div>
            {owner.bio && <p className="mt-2 max-w-150 text-[14px] leading-relaxed text-ink-mid">{owner.bio}</p>}
            <div className="mt-2.5 flex gap-4 text-[13px] text-ink-soft">
              <Link className="hover:underline" href={`${base}/follows`}><b className="text-ink">{followerCount}</b> followers</Link>
              <Link className="hover:underline" href={`${base}/follows?tab=following`}><b className="text-ink">{followingCount}</b> following</Link>
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

        {/* 카테고리 탭 — 이 블로그가 다루는 주제들 */}
        {topics.length > 1 && (
          <nav className="mt-5 flex flex-wrap gap-2">
            <Link
              href={base}
              className={`rounded-full px-3.5 py-1.5 text-[12.5px] font-bold ${!filtering ? 'bg-ink text-paper' : 'border border-hairline text-ink-mid hover:bg-surface'}`}
            >
              All
            </Link>
            {topics.map((t) => (
              <Link
                key={t.topic}
                href={`${base}?topic=${t.topic}`}
                className={`rounded-full px-3.5 py-1.5 text-[12.5px] font-bold capitalize ${filter.topic === t.topic ? 'bg-ink text-paper' : 'border border-hairline text-ink-mid hover:bg-surface'}`}
              >
                {t.topic} <span className="font-mono text-[10.5px] opacity-60">{t.count}</span>
              </Link>
            ))}
          </nav>
        )}
      </header>

      {/* 대표글 — 필터 없는 첫 화면에서만 */}
      {!filtering && pinnedPost && (
        <>
          <SectionLabel>PINNED</SectionLabel>
          <div className="grid gap-6 sm:grid-cols-2">
            <PostCard post={pinnedPost} />
          </div>
        </>
      )}

      {/* 연재 목록 */}
      {!filtering && seriesList.length > 0 && (
        <>
          <SectionLabel>SERIES</SectionLabel>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {seriesList.map((s) => (
              <Link
                key={s.series}
                href={`${base}?series=${encodeURIComponent(s.series)}`}
                className="rounded-xl border border-hairline p-4 transition-colors hover:bg-surface"
              >
                <div className="text-[15px] font-bold leading-snug">{s.series}</div>
                <div className="mt-1 text-[12px] text-ink-soft">{s.count} {s.count === 1 ? 'post' : 'posts'} · updated {timeAgo(s.latest_at)}</div>
              </Link>
            ))}
          </div>
        </>
      )}

      <SectionLabel>
        {filter.series ? `SERIES · ${filter.series}` : filter.topic ? `${filter.topic.toUpperCase()} · ${posts.length}` : `POSTS · ${posts.length}`}
      </SectionLabel>
      {filtering && (
        <p className="-mt-2 mb-4 text-[13px] text-ink-soft">
          <Link className="underline underline-offset-2 hover:text-ink" href={base}>← all posts</Link>
          {filter.series ? ' · in reading order' : ''}
        </p>
      )}
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
