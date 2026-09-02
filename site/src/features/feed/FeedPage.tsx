import Link from 'next/link';
import { headers } from 'next/headers';
import { PostCard, AdCard } from '@/components/ui';
import { fetchFeed } from './queries';
import { TabsNav } from './sections/TabsNav';

const AD_EVERY = 9; // 인피드 광고 간격 (첫 광고는 7번째 자리)

export async function FeedPage({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string; sort?: string }> }) {
  const { tab = 'all', q = '', sort = 'hot' } = await searchParams;
  const country = (await headers()).get('cf-ipcountry'); // Cloudflare 엣지가 무료로 제공 (로컬은 null)
  const posts = await fetchFeed({ tab, q, sort, country });

  const cells: React.ReactNode[] = [];
  posts.forEach((p, i) => {
    cells.push(<PostCard key={p.id} post={p} />);
    if (i === 5 || (i > 5 && (i - 5) % AD_EVERY === 0)) cells.push(<AdCard key={`ad-${i}`} />);
  });

  const sortHref = (s: string) => {
    const qs = new URLSearchParams({ ...(tab !== 'all' ? { tab } : {}), ...(s !== 'hot' ? { sort: s } : {}) }).toString();
    return qs ? `/?${qs}` : '/';
  };

  return (
    <main>
      <div className="flex items-center justify-between gap-4">
        <TabsNav active={tab} />
        <div className="flex shrink-0 gap-3 border-b border-hairline pb-3 pt-3 text-xs font-bold uppercase tracking-widest">
          <Link href={sortHref('hot')} className={sort !== 'latest' ? 'text-ink-strong' : 'text-ink-soft hover:text-ink'}>Trending</Link>
          <Link href={sortHref('latest')} className={sort === 'latest' ? 'text-ink-strong' : 'text-ink-soft hover:text-ink'}>Latest</Link>
        </div>
      </div>
      {q && <p className="mt-5 text-[13px] text-ink-soft">Search results for “{q}” — {posts.length} post{posts.length === 1 ? '' : 's'}</p>}
      {!posts.length && <p className="py-14 text-[13px] text-ink-soft">Nothing here yet.</p>}
      <div className="mt-7 grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {cells}
      </div>
    </main>
  );
}
