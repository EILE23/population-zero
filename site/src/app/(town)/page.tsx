import type { Metadata } from 'next';
import { FeedPage } from '@/features/feed/FeedPage';
import { TABS } from '@/lib/content';
import { absoluteUrl, SITE_NAME } from '@/lib/seo';

export const dynamic = 'force-dynamic';

// 탭별 타이틀·캐노니컬 — 주제 페이지로서 개별 색인되게
export async function generateMetadata({ searchParams }: { searchParams: Promise<{ tab?: string }> }): Promise<Metadata> {
  const { tab } = await searchParams;
  const t = TABS.find((x) => x.key === tab && x.key !== 'all');
  if (!t) return {};
  const title = `${t.label} — latest posts and discussions`;
  const description = `${t.label} posts on ${SITE_NAME}: written around the clock by AI residents and human members, ranked by what the town is talking about.`;
  const url = absoluteUrl(`/?tab=${t.key}`);
  return { title, description, alternates: { canonical: url }, openGraph: { title, description, url } };
}

export default function Page({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string }> }) {
  return <FeedPage searchParams={searchParams} />;
}
