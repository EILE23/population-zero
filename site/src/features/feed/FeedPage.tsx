import Link from 'next/link';
import { headers } from 'next/headers';
import { fetchFeed } from './queries';
import { TabsNav } from './sections/TabsNav';
import { FeedGrid } from './sections/FeedGrid';
import { Featured } from './sections/Featured';

export async function FeedPage({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string; sort?: string; page?: string }> }) {
  const { tab = 'all', q = '', sort = 'hot', page: pageRaw = '1' } = await searchParams;
  const page = Math.max(1, Number(pageRaw) || 1);
  const startOffset = (page - 1) * 32;
  const country = (await headers()).get('cf-ipcountry'); // Cloudflare 엣지가 무료로 제공 (로컬은 null)
  // Featured 는 홈 첫 화면에만 — 주제 탭·검색·2페이지엔 없다. 띠에 오른 글은 아래 피드에서 뺀다(두 번 보이면 채워 넣은 티가 난다)
  const showFeatured = tab === 'all' && !q && page === 1;
  const featured = showFeatured ? await fetchFeed({ country, sort: 'latest', featured: true, limit: 4 }) : [];
  const featuredIds = new Set(featured.map((p) => p.id));
  const raw = await fetchFeed({ tab, q, sort, country, offset: startOffset, limit: 32 }); // 초기 8줄(4열 기준)
  const posts = raw.filter((p) => !featuredIds.has(p.id));
  // '더 있나'는 걸러내기 전 개수로 판단한다 — 걸러낸 뒤 개수로 보면 대표글이 빠진 만큼 "끝"으로 오판해 두 줄에서 멈춘다
  const hasMore = raw.length === 32;

  // 크롤러용 페이지네이션 링크 — 무한 스크롤은 봇에게 안 보이므로 앵커로 발견 경로 제공
  const pageHref = (p: number) => {
    const qs = new URLSearchParams({ ...(tab !== 'all' ? { tab } : {}), ...(sort !== 'hot' ? { sort } : {}), ...(p > 1 ? { page: String(p) } : {}) }).toString();
    return qs ? `/?${qs}` : '/';
  };

  const sortHref = (s: string) => {
    const qs = new URLSearchParams({ ...(tab !== 'all' ? { tab } : {}), ...(s !== 'hot' ? { sort: s } : {}) }).toString();
    return qs ? `/?${qs}` : '/';
  };

  return (
    <main>
      {/* 반응형: 넓으면 탭+정렬 한 줄, 좁으면 탭 줄 아래에 정렬 줄 */}
      <div className="flex flex-wrap items-center justify-between gap-x-4">
        <div className="w-full min-w-0 basis-full md:flex-1 md:basis-auto"><TabsNav active={tab} /></div>
        <div className="ml-auto flex shrink-0 gap-3 pb-2 pt-2.5 text-xs font-bold uppercase tracking-widest md:border-b md:border-hairline md:pb-3 md:pt-3">
          <Link href={sortHref('hot')} className={sort !== 'latest' ? 'text-ink-strong' : 'text-ink-soft hover:text-ink'}>Trending</Link>
          <Link href={sortHref('latest')} className={sort === 'latest' ? 'text-ink-strong' : 'text-ink-soft hover:text-ink'}>Latest</Link>
        </div>
      </div>
      {showFeatured && <div className="mt-6"><Featured posts={featured} /></div>}
      {q && <p className="mt-5 text-[13px] text-ink-soft">Search results for “{q}” — {posts.length} post{posts.length === 1 ? '' : 's'}</p>}
      {/* 검색이 빈손으로 끝났을 때가 질문을 올릴 가장 좋은 순간이다 — 답이 없으면 물으면 된다 */}
      {!posts.length && (
        q
          ? <p className="py-14 text-[13.5px] text-ink-soft">
              Nothing matched “{q}”.{' '}
              <Link className="font-bold text-ink underline underline-offset-2" href={`/ask?q=${encodeURIComponent(q)}`}>Ask it instead</Link> and people here will answer.
            </p>
          : <p className="py-14 text-[13px] text-ink-soft">Nothing here yet.</p>
      )}
      {/* key로 탭·정렬 변경 시 리마운트 — 무한 스크롤 상태가 이전 목록을 물고 있지 않게 */}
      <FeedGrid key={`${tab}|${q}|${sort}|${page}`} initial={posts} tab={tab} q={q} sort={sort} startOffset={startOffset} hasMore={hasMore} nextOffset={startOffset + raw.length} />
      {/* 크롤러용 발견 경로 (사람은 무한 스크롤을 씀) */}
      <nav className="mt-10 flex justify-between text-[13px] font-bold text-ink-soft" aria-label="pagination">
        {page > 1 ? <Link className="hover:text-ink" href={pageHref(page - 1)} rel="prev">← Newer</Link> : <span />}
        {hasMore && <Link className="hover:text-ink" href={pageHref(page + 1)} rel="next">Older →</Link>}
      </nav>
    </main>
  );
}
