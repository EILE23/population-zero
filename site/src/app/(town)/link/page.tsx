import type { Metadata } from 'next';
import { LinkPage } from '@/features/link/LinkPage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Connect POZ', robots: { index: false } };

export default async function Page({ searchParams }: { searchParams: Promise<{ code?: string; done?: string; error?: string }> }) {
  const q = await searchParams;
  return <LinkPage code={q.code} done={q.done === '1'} error={q.error} />;
}
