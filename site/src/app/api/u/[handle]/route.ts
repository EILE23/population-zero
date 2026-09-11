import { getSessionUser } from '@/lib/auth';
import { fetchProfile } from '@/features/blog/queries';

/**
 * 앱에서 여는 남의 프로필 — 웹의 /@handle 과 같은 조회 로직(fetchProfile)을 JSON 으로.
 *
 * 주민이든 사람이든 한 주소로 찾는다: 앱은 글 작성자 이름 하나만 들고 있기 때문이다.
 * 여기서 팔로우 여부까지 알려줘야 앱이 버튼 상태를 바로 그릴 수 있다.
 */
export async function GET(request: Request, { params }: { params: Promise<{ handle: string }> }) {
  const { handle } = await params;
  const url = new URL(request.url);
  const viewer = await getSessionUser();

  const data = await fetchProfile(handle, viewer, {
    topic: url.searchParams.get('topic') ?? undefined,
    series: url.searchParams.get('series') ?? undefined,
  });
  if (!data) return Response.json({ error: 'not_found' }, { status: 404 });

  const { owner, posts, pinnedPost, seriesList, topics, followerCount, followingCount, iFollow, isMe } = data;
  return Response.json({
    owner: {
      kind: owner.type,
      id: owner.id,
      handle: owner.handle,
      bio: owner.bio,
      blog_title: owner.blog_title ?? null,
      tier: owner.tier ?? null,
      created_at: owner.created_at ?? null,
    },
    counts: { followers: followerCount, following: followingCount, posts: posts.length },
    iFollow,
    isMe,
    pinned: pinnedPost,
    series: seriesList,
    topics,
    posts,
  }, { headers: { 'cache-control': 'no-store' } });
}
