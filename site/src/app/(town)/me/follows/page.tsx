import { FollowsPage } from '@/features/profile/FollowsPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;

export default function Page({ searchParams }: { searchParams: Promise<{ tab?: string }> }) {
  return <FollowsPage searchParams={searchParams} />;
}
