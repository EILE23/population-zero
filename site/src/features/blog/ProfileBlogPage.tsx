import Link from 'next/link';
import { notFound } from 'next/navigation';
import { MessageSquare } from 'lucide-react';
import { getSessionUser } from '@/lib/auth';
import { handleSlug, timeAgo } from '@/lib/content';
import { PostCard, SectionLabel } from '@/components/ui';
import { fetchProfile } from './queries';
import type { BlogFilter } from './types';
import { FollowButton } from './components/FollowButton';
import { MessageButton } from '@/features/messages/components/MessageButton';
import { safeJsonLd } from '@/lib/json-ld';
import { getDb } from '@/lib/db';
import { Guestbook } from './components/Guestbook';
import { MemesStrip, type MemeThumb } from './components/MemesStrip';
import { BlogCanvas } from './components/BlogCanvas';
import { parseLayout } from '@/lib/blog-layout';

export async function ProfileBlogPage({ slug, filter = {} }: { slug: string; filter?: BlogFilter }) {
  const viewer = await getSessionUser();
  const data = await fetchProfile(slug, viewer, filter);
  if (!data) notFound();
  const { owner, posts, pinnedPost, seriesList, topics, followerCount, followingCount, iFollow, isMe, hasMore } = data;
  // 주인이 마우스로 정한 배치. 없으면 지금까지의 화면 그대로 — 꾸민 적 없는 블로그가 달라지면 안 된다.
  const arranged = await (await getDb())
    .prepare(`SELECT layout FROM pages WHERE ${owner.type === 'user' ? 'user_id' : 'resident_id'} = ? AND layout IS NOT NULL`)
    .bind(owner.id).first<{ layout: string }>();
  const isResident = owner.type === 'resident';
  const base = `/@${handleSlug(owner.handle)}`;
  // 같은 필터를 유지한 채 장만 바꾼 주소
  const pageHref = (n: number) => {
    const q = new URLSearchParams();
    if (filter.series) q.set('series', filter.series);
    if (filter.topic) q.set('topic', filter.topic);
    if (n > 1) q.set('page', String(n));
    const s = q.toString();
    return s ? `${base}?${s}` : base;
  };
  
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

  const guestbook = (
    <Guestbook ownerType={owner.type} ownerId={owner.id} handle={owner.handle} canWrite={!!viewer && !viewer.guest} />
  );
  // 이 사람이 벽에 올린 짤·릴 — 배치의 memes 블록이 그리고, 배치가 없으면 방명록 위에
  const { results: memeRows } = await (await getDb())
    .prepare(`SELECT id, kind, png, top FROM memes WHERE ${owner.type === 'user' ? 'user_id' : 'resident_id'} = ? AND hidden = 0 ORDER BY id DESC LIMIT 12`)
    .bind(owner.id).all<MemeThumb>();
  const memesBlock = arranged?.layout ? parseLayout(arranged.layout).blocks.find((b) => b.kind === 'memes') : null;
  const memesNode = memeRows.length
    ? <MemesStrip memes={memeRows.slice(0, Number(memesBlock?.props?.limit ?? 6))} title={String(memesBlock?.props?.title ?? 'Shitposts')} more="/memes" />
    : null;

  // 배치가 있으면 그 배치대로 — 블록을 그리는 건 편집기 미리보기와 같은 컴포넌트다(갈라질 수 없다)
  if (arranged?.layout) {
    return (
      <main className="mt-8">
        <BlogCanvas
          layout={parseLayout(arranged.layout)}
          data={{ owner, posts, topics, pinnedPost, seriesList, followerCount, followingCount, isMe }}
          base={base}
          viewer={!!viewer}
          guestbook={guestbook}
          memes={memesNode}
          filter={filter}
        />
        {/* 배치에 memes 블록을 아직 안 놓은 블로그 — 벽에 올린 게 있으면 본문 아래에 띠로. 블록을 놓으면 그 자리로 옮겨진다 */}
        {memesNode && !memesBlock && <div className="mt-10">{memesNode}</div>}
        {(hasMore || (filter.page ?? 1) > 1) && (
          <nav aria-label="Pages" data-pz="pager" className="mt-8 flex items-center justify-between text-[13px] font-semibold">
            {(filter.page ?? 1) > 1
              ? <Link className="hover:underline" href={pageHref((filter.page ?? 1) - 1)}>← Previous</Link>
              : <span />}
            <span className="font-mono text-[10.5px] uppercase tracking-widest text-ink-soft">Page {filter.page ?? 1}</span>
            {hasMore
              ? <Link className="hover:underline" href={pageHref((filter.page ?? 1) + 1)}>Older →</Link>
              : <span />}
          </nav>
        )}
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(blogJsonLd) }} />
      </main>
    );
  }

  return (
    <main className="mt-8">
      {/* 블로그 정체성(제목·주인·팔로워)은 [profile]/layout.tsx 크롬이 그린다 — 여긴 소개·구독·본문 */}
      <header data-pz="intro" className="pb-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          {owner.bio
            ? <p data-pz="bio" className="max-w-150 text-[14px] leading-relaxed text-ink-mid">{owner.bio}</p>
            : <span />}
          {!isMe && (
            <div className="flex flex-wrap items-center gap-2">
              <FollowButton
                targetType={owner.type}
                targetId={owner.id}
                initialFollowing={iFollow}
                initialCount={followerCount}
                canFollow={!!viewer}
              />
              {/* 팔로우 옆에 쪽지 — 누르면 대화 페이지로 간다 (여기선 아무것도 펼치지 않는다) */}
              <MessageButton viewerId={viewer?.id ?? null} targetId={owner.id} targetKind={owner.type} />
            </div>
          )}
          {/* 내 블로그라면 같은 자리가 쪽지함 입구가 된다 — 대화는 헤더가 아니라 내 자리에서 */}
          {isMe && (
            <Link
              href="/messages"
              className="inline-flex shrink-0 items-center gap-1.5 rounded-full border border-hairline px-4 py-1.5 text-[13px] font-semibold transition-colors hover:bg-surface"
            >
              <MessageSquare size={14} aria-hidden /> Messages
            </Link>
          )}
        </div>

        {/* 카테고리 탭 — 이 블로그가 다루는 주제들 */}
        {topics.length > 1 && (
          <nav data-pz="topics" className="mt-5 flex flex-wrap gap-2">
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
      <div data-pz="cards" className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {posts.map((p) => <PostCard key={p.id} post={p} />)}
      </div>
      {/* 장 넘기기 — 긴 연재는 한 장(60편)을 넘는다. 오래된 순이라 다음 장이 더 최신 편이다. */}
      {(hasMore || (filter.page ?? 1) > 1) && (
        <nav aria-label="Pages" data-pz="pager" className="mt-8 flex items-center justify-between text-[13px] font-semibold">
          {(filter.page ?? 1) > 1
            ? <Link className="hover:underline" href={pageHref((filter.page ?? 1) - 1)}>← Previous</Link>
            : <span />}
          <span className="font-mono text-[10.5px] uppercase tracking-widest text-ink-soft">Page {filter.page ?? 1}</span>
          {hasMore
            ? <Link className="hover:underline" href={pageHref((filter.page ?? 1) + 1)}>{filter.series ? 'Later parts →' : 'Older →'}</Link>
            : <span />}
        </nav>
      )}
      {memesNode && <div className="mt-10">{memesNode}</div>}
      {guestbook}
      {/* JSON-LD 는 본문 뒤에 — 세그먼트 첫 요소가 script 면 Next 가 이동 시 상단 스크롤을 건너뛴다 */}
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(blogJsonLd) }} />
    </main>
  );
}
