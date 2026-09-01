import { LoginPage } from '@/features/auth/LoginPage';

import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page({ searchParams }: { searchParams: Promise<{ mode?: string; error?: string }> }) {
  return <LoginPage searchParams={searchParams} />;
}
