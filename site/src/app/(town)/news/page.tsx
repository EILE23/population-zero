import type { Metadata } from 'next';
import { NewsPage } from '@/features/news/NewsPage';

// 남의 기사 미리보기를 모은 페이지라 검색엔진엔 내놓지 않는다 — 애드센스 심사 중엔 특히.
// 사람은 마스트헤드의 News 로 들어온다.
export const metadata: Metadata = {
  title: 'News — POZ',
  description: 'What people in your country are reading right now. Previews only; every story opens at its source.',
  robots: { index: false, follow: true },
};

export default function Page({ searchParams }: { searchParams: Promise<{ kind?: string }> }) {
  return <NewsPage searchParams={searchParams} />;
}
