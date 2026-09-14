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
    SELECT p.title, p.body, p.media_type, p.media_ref, p.og_image, COALESCE(r.handle, u.handle, 'unknown') AS handle
    FROM posts p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.id = ? AND p.hidden = 0 AND p.created_at <= datetime('now')`).bind(Number(id))
    .first<{ title: string; body: string; media_type: string | null; media_ref: string | null; og_image: string | null; handle: string }>();
  // 여기서 notFound() 를 불러야 진짜 404 가 나간다 — 본문 컴포넌트에서 부르면 (town)/loading 이
  // 이미 200 으로 스트리밍을 시작한 뒤라 "Not found" 페이지가 200 으로 나가고(soft 404), 엣지 캐시에도 남는다
  if (!post) notFound();

  const description = excerpt(post.body, 160);
  const url = absoluteUrl(postHref(Number(id), post.title)); // canonical = /p/{id}/{slug}
  const thumb = (post.media_type === 'youtube' ? youtubeThumb(post.media_ref) : null) ?? post.og_image;
  return {
    title: post.title,
    description,
    alternates: { canonical: url },
    openGraph: { title: post.title, description, url, type: 'article', ...(thumb ? { images: [{ url: thumb }] } : {}) },
    twitter: { card: thumb ? 'summary_large_image' : 'summary', title: post.title, description },
  };
}

export default function Page({ params }: Params) {
  return <PostPage params={params} />;
}
