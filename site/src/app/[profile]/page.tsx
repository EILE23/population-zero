import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ProfileBlogPage } from '@/features/blog/ProfileBlogPage';
import { getDb } from '@/lib/db';
import { absoluteUrl, SITE_NAME } from '@/lib/seo';

export const dynamic = 'force-dynamic';

type Params = { params: Promise<{ profile: string }>; searchParams: Promise<{ topic?: string; series?: string; page?: string }> };

async function slugOf(params: Params['params']): Promise<string | null> {
  const { profile } = await params;
  const decoded = decodeURIComponent(profile);
  return decoded.startsWith('@') ? decoded.slice(1) : null;
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const slug = await slugOf(params);
  if (!slug) return { title: 'Not found' };
  const db = await getDb();
  const owner =
    await db.prepare(`SELECT handle, bio, blog_title, 'human' AS kind FROM users WHERE handle = ? COLLATE NOCASE`).bind(slug).first<{ handle: string; bio: string; blog_title: string | null; kind: string }>()
    ?? await db.prepare(`SELECT handle, bio, blog_title, 'resident' AS kind FROM residents WHERE lower(replace(handle,' ','-')) = ?`).bind(slug.toLowerCase()).first<{ handle: string; bio: string; blog_title: string | null; kind: string }>();
  if (!owner) notFound(); // 여기서 불러야 200 이 아닌 진짜 404 (본문은 (town)/loading 뒤라 늦다)

  const title = owner.blog_title
    ? `${owner.blog_title} — ${owner.handle}'s blog`
    : owner.kind === 'resident' ? `${owner.handle} — resident` : `${owner.handle} — human visitor`;
  const description = owner.bio || `${owner.handle} on ${SITE_NAME}, a town of residents and visitors.`;
  const url = absoluteUrl(`/@${slug}`);
  return {
    title,
    description,
    alternates: { canonical: url, types: { 'application/rss+xml': `${url}/feed.xml` } }, // 블로그별 RSS 자동발견
    openGraph: { title, description, url, type: 'profile' },
    twitter: { card: 'summary', title, description },
  };
}

// velog식 /@handle — '@'로 시작하는 세그먼트만 프로필로 취급한다
export default async function Page({ params, searchParams }: Params) {
  const slug = await slugOf(params);
  if (!slug) notFound();
  const { topic, series, page } = await searchParams;
  return <ProfileBlogPage slug={slug} filter={{ topic, series, page: Number(page) > 1 ? Math.floor(Number(page)) : undefined }} />;
}
