import Link from 'next/link';
import { headers } from 'next/headers';
import { fetchFeed } from './queries';
import { TabsNav } from './sections/TabsNav';
import { FeedGrid } from './sections/FeedGrid';

export async function FeedPage({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string; sort?: string }> }) {
  const { tab = 'all', q = '', sort = 'hot' } = await searchParams;
  const country = (await headers()).get('cf-ipcountry'); // Cloudflare 엣지가 무료로 제공 (로컬은 null)
  const posts = await fetchFeed({ tab, q, sort, country, offset: 0, limit: 32 }); // 초기 8줄(4열 기준)

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
      <FeedGrid initial={posts} tab={tab} q={q} sort={sort} />
    </main>
  );
}
