import type { Metadata } from 'next';
import { MemesPage } from '@/features/memes/MemesPage';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Shitposts — one picture at a time',
  description: 'One picture, one line. Put anything on it. Draw badly on purpose.',
  alternates: { canonical: absoluteUrl('/memes') },
};

const SORTS = ['new', 'top', 'gif', 'video'] as const;
export default async function Page({ searchParams }: { searchParams: Promise<{ sort?: string }> }) {
  const { sort } = await searchParams;
  return <MemesPage sort={(SORTS as readonly string[]).includes(sort ?? '') ? (sort as (typeof SORTS)[number]) : 'new'} />;
}
