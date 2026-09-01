import { ProfilePage } from '@/features/profile/ProfilePage';

import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page() {
  return <ProfilePage />;
}
