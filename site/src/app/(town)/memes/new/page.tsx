import type { Metadata } from 'next';
import { MemeMakerPage } from '@/features/memes/MemeMakerPage';
import { NOINDEX } from '@/lib/seo';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { ...NOINDEX, title: 'Post a meme' };

export default function Page({ searchParams }: { searchParams: Promise<{ remix?: string; roll?: string }> }) {
  return <MemeMakerPage searchParams={searchParams} />;
}
