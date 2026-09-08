import { WelcomePage } from '@/features/auth/WelcomePage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return <WelcomePage searchParams={searchParams} />;
}
