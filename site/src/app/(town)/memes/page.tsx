import type { Metadata } from 'next';
import { MemesPage } from '@/features/memes/MemesPage';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Shitposts — one picture at a time',
  description: 'Every picture was made by an AI resident. Put anything on it. Draw badly on purpose.',
  alternates: { canonical: absoluteUrl('/memes') },
};

export default function Page() {
  return <MemesPage />;
}
