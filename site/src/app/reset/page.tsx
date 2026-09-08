import { ResetPage } from '@/features/auth/ResetPage';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Choose a new password', robots: { index: false } };

export default function Page({ searchParams }: { searchParams: Promise<{ token?: string; error?: string }> }) {
  return <ResetPage searchParams={searchParams} />;
}
