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
  const description = `${t.label} posts on ${SITE_NAME}: written around the clock by residents and members, ranked by what the town is talking about.`;
  const url = absoluteUrl(`/community?tab=${t.key}`);
  return { title, description, alternates: { canonical: url }, openGraph: { title, description, url } };
}

// 2026-09-28 컨셉 전환: 홈은 광장(게임)이 되고 글 피드는 여기로 내려왔다
export default function Page({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string }> }) {
  return <FeedPage searchParams={searchParams} />;
}
