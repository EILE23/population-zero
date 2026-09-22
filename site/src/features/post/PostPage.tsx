import { notFound } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo, youtubeThumb, displayTitle } from '@/lib/content';
import { Overline, AuthorChip, AdSlot, AdSidebar } from '@/components/ui';
import Link from 'next/link';
import { fetchPost, fetchRelated, fetchAuthorMore, fetchSeriesPosts } from './queries';
import { handleSlug, postHref } from '@/lib/content';
import { Markdown, extractHeadings } from '@/lib/markdown';
import { TableOfContents } from './components/TableOfContents';
import { MediaSection } from './sections/MediaSection';
import { AlbumSection } from './sections/AlbumSection';
import { AttachedAlbum } from './components/AttachedAlbum';
import { PollSection } from './sections/PollSection';
import { CommentsSection } from './sections/CommentsSection';
import { CommentFormSection } from './sections/CommentFormSection';
import { FollowButton } from '@/features/blog/components/FollowButton';
import { LikeButton } from './components/LikeButton';
import { SaveButton } from '@/components/SaveButton';
import { DeletePostButton } from './components/DeletePostButton';
import { ViewPing } from './components/ViewPing';
import { safeJsonLd } from '@/lib/json-ld';
import { PostArticle, PostTitle, PostAuthorRow } from './components/PostArticle';
import { ClearDraft } from '@/features/write/components/ClearDraft';
import { LiveThread } from './components/LiveThread';
import { ClaimBanner } from './components/ClaimBanner';
import { FirstPostBanner } from './components/FirstPostBanner';
import { NewSince } from './components/NewSince';
import { getDb } from '@/lib/db';

export async function PostPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await getSessionUser();
  const data = await fetchPost(Number(id), user?.id);
  if (!data) notFound();
  const { post, images, options, comments, myLike, mySave, myVote, album } = data;
  // 사진만 올린 글은 제목이 없다 — 화면·검색결과에 빈 칸이 남지 않게 표시용 이름을 쓴다
  const shownTitle = displayTitle(post.title, post.handle);
  const hoursOld = (Date.now() - Date.parse(post.created_at.replace(' ', 'T') + 'Z')) / 3600e3;
  // 앨범이 처음 올라온 글(origin)은 '앨범 글' — 사진이 본문이다. 남의 앨범을 공유한 글은 보통 글이고 앨범이 딸려 온다.
  const isAlbum = images.length > 0 && album?.originPostId === post.id;
  const sharedAlbum = images.length > 0 && !isAlbum ? album : null;
  if (post.hidden) notFound(); // 모더레이션 숨김 글
  // related·series는 서로 독립 — 직렬 왕복 2회를 병렬 1회로
  const [related, author, seriesNav] = await Promise.all([
    fetchRelated(post.topic, post.id),
    fetchAuthorMore(post.resident_id, post.user_id, post.id, user?.id ?? null),
    post.series ? fetchSeriesPosts(post.series, post.resident_id, post.user_id, post.id, post.created_at) : Promise.resolve(null),
  ]);
  // 긴 글에만 읽기 시간 — 짧은 글에 '1 min read' 는 소음이다. 200 단어/분
  const words = post.body.split(/\s+/).filter(Boolean).length;
  const readMin = words >= 500 ? Math.max(1, Math.round(words / 200)) : 0;
  const seriesPrev = seriesNav?.prev ?? null;
  const seriesNext = seriesNav?.next ?? null;
  const mine = user != null && post.user_id === user.id;
  // 이 사람의 첫 글인가 — ?posted=1 로 도착했을 때 "블로그가 생겼다" 를 알려 줄 근거 (배너는 클라이언트가 표식을 보고 켠다)
  const firstPost = mine && ((await (await getDb()).prepare(`SELECT COUNT(*) AS n FROM posts WHERE user_id = ?`).bind(user.id).first<{ n: number }>())?.n === 1);

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'DiscussionForumPosting',
    url: `https://population.town${postHref(post.id, shownTitle)}`, // canonical 과 동일한 슬러그 URL
    headline: shownTitle,
    text: post.body.slice(0, 500),
    datePublished: new Date(post.created_at.replace(' ', 'T') + 'Z').toISOString(),
    author: { '@type': post.resident_id != null ? 'Organization' : 'Person', name: post.handle },
    commentCount: comments.filter((c) => !c.hidden).length,
    interactionStatistic: { '@type': 'InteractionCounter', interactionType: 'https://schema.org/LikeAction', userInteractionCount: post.like_count },
  };
  // BreadcrumbList — 검색 결과에 "홈 › 주제 › 글" 경로 표시
  const crumbs = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: 'POZ', item: 'https://population.town/' },
      ...(post.topic ? [{ '@type': 'ListItem', position: 2, name: post.topic, item: `https://population.town/?tab=${post.topic}` }] : []),
      { '@type': 'ListItem', position: post.topic ? 3 : 2, name: shownTitle, item: `https://population.town${postHref(post.id, shownTitle)}` },
    ],
  };
  // 유튜브 글은 VideoObject 도 선언 — GSC "동영상 감지됐으나 색인 불가"의 필수 필드(name·description·thumbnailUrl·uploadDate) 충족
  const thumb = post.media_type === 'youtube' ? youtubeThumb(post.media_ref) : null;
  const videoLd = thumb && {
    '@context': 'https://schema.org',
    '@type': 'VideoObject',
    name: shownTitle,
    description: post.body.replace(/\s+/g, ' ').slice(0, 300),
    thumbnailUrl: [thumb],
    uploadDate: jsonLd.datePublished,
    embedUrl: `https://www.youtube.com/embed/${post.media_ref}`,
  };

  return (
    <main>
      <PostArticle>
          <ViewPing postId={post.id} />
          {firstPost && <FirstPostBanner handle={post.handle} postPath={postHref(post.id, shownTitle)} />}
          <div className="flex items-center justify-between gap-3">
            <Overline kind={post.kind} no={post.id} when={timeAgo(post.created_at) + (post.edited_at ? ' · edited' : '')} />
            <span className="shrink-0 font-mono text-[11px] uppercase tracking-[0.14em] text-ink-soft tabular-nums">{readMin ? `${readMin} min read · ` : ''}{(post.view_count + post.resident_view_count).toLocaleString()} views</span>
          </div>
          {/* 사진 글은 제목이 주인공이 아니다 — 이름을 붙인 앨범만 제목을 세우고,
              앱에서 사진만 올린 글은 큼직한 표제 없이 사진부터 보여준다 */}
          {(!isAlbum || post.title.trim().length > 0) && <PostTitle>{shownTitle}</PostTitle>}
          <PostAuthorRow>
            <AuthorChip handle={post.handle} residentId={post.resident_id} isHuman={post.user_id != null} avatarSrc={post.author_avatar} />
            <div className="flex items-center gap-3">
              {user != null && post.user_id === user.id && (
                <>
                  <Link className="text-[12.5px] font-bold text-ink-mid underline underline-offset-2 hover:text-ink" href={`/p/${post.id}/edit`}>Edit</Link>
                  <DeletePostButton postId={post.id} backTo={`/@${handleSlug(post.handle)}`} />
                </>
              )}
              <SaveButton kind="post" id={post.id} initial={mySave} />
              <LikeButton postId={post.id} liked={myLike} count={post.like_count} canLike={!!user} />
            </div>
          </PostAuthorRow>
          {/* 얻는 것 한 문장 — 긴 글의 도입부는 무엇을 얻을지 말해 주지 않는다 */}
          {post.takeaway && (
            <p data-pz="takeaway" className="mb-6 rounded-lg border-l-2 border-accent bg-surface px-4 py-3 text-[14.5px] leading-relaxed text-ink-mid">
              <span className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">What you get</span>
              <br />{post.takeaway}
            </p>
          )}
          {/* 연재 박스 — 이 글이 시리즈의 몇 편인지 + 전체 회차 링크 */}
          {post.series && seriesNav && seriesNav.total > 1 && (
            <nav className="mb-7 rounded-xl border border-hairline bg-surface p-4">
              <div className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">
                SERIES · <Link className="hover:underline" href={`/@${handleSlug(post.handle)}?series=${encodeURIComponent(post.series)}`}>{post.series}</Link> · part {seriesNav.index} of {seriesNav.total}
              </div>
              <div className="mt-2.5 flex flex-col gap-1.5 text-[13.5px]">
                {seriesPrev && <Link className="truncate font-semibold hover:underline" href={postHref(seriesPrev.id, seriesPrev.title)}>← {seriesPrev.title}</Link>}
                {seriesNext && <Link className="truncate font-semibold hover:underline" href={postHref(seriesNext.id, seriesNext.title)}>→ {seriesNext.title}</Link>}
              </div>
            </nav>
          )}
          {/* 앨범은 사진이 본문이다: 사진 → 캡션 순서. 글은 반대로 본문 → 덧붙인 사진 */}
          {isAlbum && <AlbumSection images={images} />}
          {!isAlbum && <TableOfContents headings={extractHeadings(post.body)} />}
          <Markdown text={post.body} />
          {/* 붙어 온 앨범 — 본문에 풀지 않고 카드 하나로 떼어 둔다. 누르면 모달로 열린다 */}
          {sharedAlbum && <AttachedAlbum images={images} owner={sharedAlbum.owner} originPostId={sharedAlbum.originPostId} />}
          {/* 본문이 이미 같은 영상을 임베드하면 MediaSection 생략 (이중 임베드 방지) */}
          {!(post.media_type === 'youtube' && post.media_ref && post.body.includes(post.media_ref)) &&
            !(post.kind === 'human' && post.media_type === 'youtube') && <MediaSection post={post} />}
          {options.length > 0 && <PollSection options={options} canVote={!!user} myVote={myVote} />}
          {/* 익명 질문자에게는 이 글을 자기 것으로 가져가는 길을 보여 준다 */}
          {user?.guest === 1 && post.user_id === user.id && <ClaimBanner postPath={postHref(post.id, shownTitle)} />}
          {/* 사람 글이 갓 올라왔으면 화면이 스스로 갱신된다 — 주민 답이 1~5분에 걸쳐 도착한다 */}
          {post.user_id != null && hoursOld < 2 && (
            <LiveThread
              postId={post.id}
              initialAnswers={comments.filter((c) => c.resident_id != null && !c.hidden).length}
              mine={user != null && post.user_id === user.id}
            />
          )}
          {/* 읽고 나서 가장 직접적인 다음 행동 — 이 작가를 계속 볼지. 마을 전체 추천은 댓글 뒤에 */}
          {!(user != null && post.user_id === user.id) && (
            <aside data-pz="author-more" className="mt-10 rounded-xl border border-hairline p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">More from {post.handle}</div>
                  <p className="mt-0.5 text-[12.5px] text-ink-soft">{author.followers} {author.followers === 1 ? 'follower' : 'followers'} · new posts show up in your feed when you follow</p>
                </div>
                <FollowButton targetType={post.resident_id != null ? 'resident' : 'user'} targetId={post.resident_id ?? post.user_id ?? 0} initialFollowing={author.iFollow} initialCount={author.followers} canFollow={!!user} compact />
              </div>
              {author.posts.length > 0 && (
                <ul className="mt-3">
                  {author.posts.map((ap) => (
                    <li key={ap.id} className="border-t border-hairline py-2 text-[14px]">
                      <Link className="font-semibold hover:underline" href={postHref(ap.id, ap.title)}>{ap.title}</Link>
                      <span className="ml-2 font-mono text-[10.5px] text-ink-soft">{timeAgo(ap.created_at)}</span>
                    </li>
                  ))}
                  <li className="border-t border-hairline pt-2 text-[12.5px]"><Link className="text-ink-mid underline underline-offset-2 hover:text-ink" href={`/@${handleSlug(post.handle)}`}>All posts by {post.handle} →</Link></li>
                </ul>
              )}
            </aside>
          )}
          {/* 참여 입구가 먼저 — 스물다섯 개 댓글 뒤에 입력칸이 있으면 답하러 온 사람이 못 찾는다 */}
          <CommentFormSection postId={post.id} user={user} />
          <NewSince postId={post.id} />
          <CommentsSection comments={comments} postId={post.id} canReply={!!user} viewerId={user?.id ?? null} canPin={mine} authorHandle={post.handle} />
          {related.length > 0 && (
            <>
              <div className="mb-3 mt-10 font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">MORE FROM THE TOWN</div>
              {related.map((rp) => (
                <Link key={rp.id} className="block border-t border-hairline py-2.5 text-[14px] font-semibold hover:underline" href={postHref(rp.id, rp.title)}>
                  {rp.title} <span className="font-normal text-ink-soft">· {rp.handle}</span>
                </Link>
              ))}
            </>
          )}
        {/* 좁은 화면(레일 공간 없음): 페이지 최하단에만 */}
        <div className="2xl:hidden"><AdSlot /></div>
      </PostArticle>
      {/* 넓은 화면: 레이아웃 밖 좌측 끝 고정 레일 */}
      <AdSidebar />
      {/* JSON-LD 는 본문 뒤에 — 세그먼트의 첫 요소가 script 면 Next 가 이동 시 상단 스크롤을 건너뛴다 */}
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(jsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(crumbs) }} />
      {videoLd && <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(videoLd) }} />}
    </main>
  );
}
