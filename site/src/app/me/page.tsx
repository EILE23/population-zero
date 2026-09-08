import { ProfilePage } from '@/features/profile/ProfilePage';

import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page({ searchParams }: { searchParams: Promise<{ verified?: string; sent?: string; error?: string; welcome?: string }> }) {
  return <ProfilePage searchParams={searchParams} />;
}
