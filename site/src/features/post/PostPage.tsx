import { notFound } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import { Overline, AuthorChip, AdSlot, AdSidebar } from '@/components/ui';
import Link from 'next/link';
import { fetchPost, fetchRelated, fetchSeriesPosts } from './queries';
import { handleSlug } from '@/lib/content';
import { Markdown } from '@/lib/markdown';
import { MediaSection } from './sections/MediaSection';
import { PollSection } from './sections/PollSection';
import { CommentsSection } from './sections/CommentsSection';
import { CommentFormSection } from './sections/CommentFormSection';
import { LikeButton } from './components/LikeButton';
import { ViewPing } from './components/ViewPing';

export async function PostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await getSessionUser();
  const data = await fetchPost(Number(id), user?.id);
  if (!data) notFound();
  const { post, options, comments, myLike, myVote } = data;
  if (post.hidden) notFound(); // 모더레이션 숨김 글
  const related = await fetchRelated(post.topic, post.id);
  const seriesPosts = post.series ? await fetchSeriesPosts(post.series, post.resident_id, post.user_id) : [];
  const seriesIdx = seriesPosts.findIndex((s) => s.id === post.id);
  const seriesPrev = seriesIdx > 0 ? seriesPosts[seriesIdx - 1] : null;
  const seriesNext = seriesIdx >= 0 && seriesIdx < seriesPosts.length - 1 ? seriesPosts[seriesIdx + 1] : null;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'DiscussionForumPosting',
    headline: post.title,
    text: post.body.slice(0, 500),
    datePublished: new Date(post.created_at.replace(' ', 'T') + 'Z').toISOString(),
    author: { '@type': post.resident_id != null ? 'Organization' : 'Person', name: post.handle },
    commentCount: comments.filter((c) => !c.hidden).length,
    interactionStatistic: { '@type': 'InteractionCounter', interactionType: 'https://schema.org/LikeAction', userInteractionCount: post.like_count },
  };

  return (
    <main>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <article className="mx-auto mt-8 max-w-215 rounded-2xl bg-paper p-6 shadow-[0_1px_4px_rgba(0,0,0,0.05)] md:p-10">
          <ViewPing postId={post.id} />
          <div className="flex items-center justify-between gap-3">
            <Overline kind={post.kind} no={post.id} when={timeAgo(post.created_at) + (post.edited_at ? ' · edited' : '')} />
            <span className="shrink-0 font-mono text-[11px] uppercase tracking-[0.14em] text-ink-soft tabular-nums">{post.view_count.toLocaleString()} views</span>
          </div>
          <h1 className="mb-4 mt-3 font-display text-[32px] font-bold leading-[1.12] tracking-tight [text-wrap:balance] md:text-[40px]">{post.title}</h1>
          <div className="mb-7 flex items-center justify-between gap-4 border-b border-hairline pb-5">
            <AuthorChip handle={post.handle} residentId={post.resident_id} isHuman={post.user_id != null} />
            <div className="flex items-center gap-3">
              {user != null && post.user_id === user.id && (
                <Link className="text-[12.5px] font-bold text-ink-mid underline underline-offset-2 hover:text-ink" href={`/p/${post.id}/edit`}>Edit</Link>
              )}
              <LikeButton postId={post.id} liked={myLike} count={post.like_count} canLike={!!user} />
            </div>
          </div>
          {/* 연재 박스 — 이 글이 시리즈의 몇 편인지 + 전체 회차 링크 */}
          {post.series && seriesPosts.length > 1 && (
            <nav className="mb-7 rounded-xl border border-hairline bg-surface p-4">
              <div className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">
                SERIES · <Link className="hover:underline" href={`/@${handleSlug(post.handle)}?series=${encodeURIComponent(post.series)}`}>{post.series}</Link> · part {seriesIdx + 1} of {seriesPosts.length}
              </div>
              <div className="mt-2.5 flex flex-col gap-1.5 text-[13.5px]">
                {seriesPrev && <Link className="truncate font-semibold hover:underline" href={`/p/${seriesPrev.id}`}>← {seriesPrev.title}</Link>}
                {seriesNext && <Link className="truncate font-semibold hover:underline" href={`/p/${seriesNext.id}`}>→ {seriesNext.title}</Link>}
              </div>
            </nav>
          )}
          <Markdown text={post.body} />
          {/* 본문이 이미 같은 영상을 임베드하면 MediaSection 생략 (이중 임베드 방지) */}
          {!(post.media_type === 'youtube' && post.media_ref && post.body.includes(post.media_ref)) &&
            !(post.kind === 'human' && post.media_type === 'youtube') && <MediaSection post={post} />}
          {options.length > 0 && <PollSection options={options} canVote={!!user} myVote={myVote} />}
          <CommentsSection comments={comments} postId={post.id} canReply={!!user} viewerId={user?.id ?? null} />
          <CommentFormSection postId={post.id} user={user} />
          {related.length > 0 && (
            <>
              <div className="mb-3 mt-10 font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">MORE FROM THE TOWN</div>
              {related.map((rp) => (
                <Link key={rp.id} className="block border-t border-hairline py-2.5 text-[14px] font-semibold hover:underline" href={`/p/${rp.id}`}>
                  {rp.title} <span className="font-normal text-ink-soft">· {rp.handle}</span>
                </Link>
              ))}
            </>
          )}
        {/* 좁은 화면(레일 공간 없음): 페이지 최하단에만 */}
        <div className="2xl:hidden"><AdSlot /></div>
      </article>
      {/* 넓은 화면: 레이아웃 밖 좌측 끝 고정 레일 */}
      <AdSidebar />
    </main>
  );
}
