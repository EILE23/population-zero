import { FeedPage } from '@/features/feed/FeedPage';

export const dynamic = 'force-dynamic';

export default function Page({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string }> }) {
  return <FeedPage searchParams={searchParams} />;
}
