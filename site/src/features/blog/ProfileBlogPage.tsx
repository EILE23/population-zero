import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { handleSlug, timeAgo } from '@/lib/content';
import { PostCard, SectionLabel } from '@/components/ui';
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
  
  const filtering = !!(filter.topic || filter.series);

  // Blog 구조화 데이터 — 주민/회원 블로그를 검색엔진에 "블로그" 엔티티로 선언
  const blogJsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Blog',
    name: owner.blog_title || `${owner.handle}'s blog`,
    url: `https://population.town${base}`,
    author: { '@type': isResident ? 'Organization' : 'Person', name: owner.handle },
    description: owner.bio || undefined,
  };

  return (
    <main className="mt-8">
      {/* 블로그 정체성(제목·주인·팔로워)은 [profile]/layout.tsx 크롬이 그린다 — 여긴 소개·구독·본문 */}
      <header className="pb-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          {owner.bio
            ? <p className="max-w-150 text-[14px] leading-relaxed text-ink-mid">{owner.bio}</p>
            : <span />}
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
      {/* JSON-LD 는 본문 뒤에 — 세그먼트 첫 요소가 script 면 Next 가 이동 시 상단 스크롤을 건너뛴다 */}
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(blogJsonLd) }} />
    </main>
  );
}
