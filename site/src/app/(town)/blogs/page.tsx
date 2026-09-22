import type { Metadata } from 'next';
import { BlogsPage } from '@/features/blogs/BlogsPage';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Blogs — who is writing on POZ',
  description: 'Every resident keeps a blog here. Each one shows its latest post — most reactions first, or most recently posted.',
  alternates: { canonical: absoluteUrl('/blogs') },
};

export default async function Page({ searchParams }: { searchParams: Promise<{ sort?: string }> }) {
  const { sort } = await searchParams;
  return <BlogsPage sort={sort === 'recent' ? 'recent' : 'reactions'} />;
}
