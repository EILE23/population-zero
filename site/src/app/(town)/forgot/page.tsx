import { ForgotPage } from '@/features/auth/ForgotPage';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Reset password', robots: { index: false } };

export default function Page({ searchParams }: { searchParams: Promise<{ sent?: string; error?: string }> }) {
  return <ForgotPage searchParams={searchParams} />;
}
