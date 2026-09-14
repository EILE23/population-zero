import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PostPage } from '@/features/post/PostPage';
import { getDb } from '@/lib/db';
import { excerpt, youtubeThumb, postHref } from '@/lib/content';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';

type Params = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { id } = await params;
  const db = await getDb();
  const post = await db.prepare(`
    SELECT p.title, p.body, p.media_type, p.media_ref, p.og_image, COALESCE(r.handle, u.handle, 'unknown') AS handle,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) AS comment_count
    FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.id = ? AND p.hidden = 0 AND p.created_at <= datetime('now')`).bind(Number(id))
    .first<{ title: string; body: string; media_type: string | null; media_ref: string | null; og_image: string | null; handle: string; comment_count: number }>();
  // 여기서 notFound() 를 불러야 진짜 404 가 나간다 — 본문 컴포넌트에서 부르면 (town)/loading 이
  // 이미 200 으로 스트리밍을 시작한 뒤라 "Not found" 페이지가 200 으로 나가고(soft 404), 엣지 캐시에도 남는다
  if (!post) notFound();

  const description = excerpt(post.body, 160);
  const url = absoluteUrl(postHref(Number(id), post.title)); // canonical = /p/{id}/{slug}
  const thumb = (post.media_type === 'youtube' ? youtubeThumb(post.media_ref) : null) ?? post.og_image;
  // 짧은 글(500자 미만 — 사이트맵과 같은 기준)은 색인에서 뺀다. 댓글 유무는 안 본다: 주민이 거의 모든 글에
  // 댓글을 달아서 그 조건을 넣으면 85개 중 6개만 걸린다. 사이트엔 그대로 있고 링크는 따라간다.
  // 색인된 페이지의 평균이 곧 "콘텐츠 품질" 판정이라, 분모에서 얇은 페이지를 덜어낸다.
  const thin = post.body.trim().length < 500;
  return {
    title: post.title,
    description,
    alternates: { canonical: url },
    ...(thin ? { robots: { index: false, follow: true } } : {}),
    openGraph: { title: post.title, description, url, type: 'article', ...(thumb ? { images: [{ url: thumb }] } : {}) },
    twitter: { card: thumb ? 'summary_large_image' : 'summary', title: post.title, description },
  };
}

export default function Page({ params }: Params) {
  return <PostPage params={params} />;
}
