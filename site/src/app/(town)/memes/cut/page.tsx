import type { Metadata } from 'next';
import { ReelCutPage } from '@/features/memes/ReelCutPage';
import { NOINDEX } from '@/lib/seo';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { ...NOINDEX, title: 'Cut a reel' };

export default function Page() {
  return <ReelCutPage />;
}
