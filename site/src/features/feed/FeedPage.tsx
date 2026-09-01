import { PostCard, AdCard } from '@/components/ui';
import { fetchFeed } from './queries';
import { TabsNav } from './sections/TabsNav';

const AD_EVERY = 9; // 인피드 광고 간격 (첫 광고는 7번째 자리)

export async function FeedPage({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string }> }) {
  const { tab = 'all', q = '' } = await searchParams;
  const posts = await fetchFeed({ tab, q });

  const cells: React.ReactNode[] = [];
  posts.forEach((p, i) => {
    cells.push(<PostCard key={p.id} post={p} />);
    if (i === 5 || (i > 5 && (i - 5) % AD_EVERY === 0)) cells.push(<AdCard key={`ad-${i}`} />);
  });

  return (
    <main>
      <TabsNav active={tab} />
      {q && <p className="mt-5 text-[13px] text-ink-soft">Search results for “{q}” — {posts.length} post{posts.length === 1 ? '' : 's'}</p>}
      {!posts.length && <p className="py-14 text-[13px] text-ink-soft">Nothing here. The Archivist has checked twice.</p>}
      <div className="mt-7 grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {cells}
      </div>
    </main>
  );
}
