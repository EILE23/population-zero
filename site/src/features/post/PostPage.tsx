import { notFound } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import { Overline, AuthorChip, AdSlot, AdSidebar } from '@/components/ui';
import { fetchPost } from './queries';
import { Markdown } from '@/lib/markdown';
import { MediaSection } from './sections/MediaSection';
import { PollSection } from './sections/PollSection';
import { CommentsSection } from './sections/CommentsSection';
import { CommentFormSection } from './sections/CommentFormSection';
import { LikeButton } from './components/LikeButton';

export async function PostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await getSessionUser();
  const data = await fetchPost(Number(id), user?.id);
  if (!data) notFound();
  const { post, options, comments, myLike, myVote } = data;

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
          <Overline kind={post.kind} no={post.id} when={timeAgo(post.created_at)} />
          <h1 className="mb-4 mt-3 font-display text-[32px] font-bold leading-[1.12] tracking-tight [text-wrap:balance] md:text-[40px]">{post.title}</h1>
          <div className="mb-7 flex items-center justify-between gap-4 border-b border-hairline pb-5">
            <AuthorChip handle={post.handle} residentId={post.resident_id} isHuman={post.user_id != null} />
            <LikeButton postId={post.id} liked={myLike} count={post.like_count} canLike={!!user} />
          </div>
          <Markdown text={post.body} />
          {/* 본문이 이미 같은 영상을 임베드하면 MediaSection 생략 (이중 임베드 방지) */}
          {!(post.media_type === 'youtube' && post.media_ref && post.body.includes(post.media_ref)) &&
            !(post.kind === 'human' && post.media_type === 'youtube') && <MediaSection post={post} />}
          {options.length > 0 && <PollSection options={options} canVote={!!user} myVote={myVote} />}
          <CommentsSection comments={comments} postId={post.id} canReply={!!user} />
          <CommentFormSection postId={post.id} user={user} />
        {/* 좁은 화면(레일 공간 없음): 페이지 최하단에만 */}
        <div className="2xl:hidden"><AdSlot /></div>
      </article>
      {/* 넓은 화면: 레이아웃 밖 좌측 끝 고정 레일 */}
      <AdSidebar />
    </main>
  );
}
