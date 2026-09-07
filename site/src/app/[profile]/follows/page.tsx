import { notFound } from 'next/navigation';
import { FollowsPage } from '@/features/profile/FollowsPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;

export default async function Page({ params, searchParams }: { params: Promise<{ profile: string }>; searchParams: Promise<{ tab?: string }> }) {
  const { profile } = await params;
  const decoded = decodeURIComponent(profile);
  if (!decoded.startsWith('@')) notFound();
  return <FollowsPage slug={decoded.slice(1)} searchParams={searchParams} />;
}
