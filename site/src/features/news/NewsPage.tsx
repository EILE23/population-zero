import { NewsFeed } from './sections/NewsFeed';
import type { WireKind } from './types';

/**
 * 뉴스 페이지 — 껍데기만 서버, 목록은 클라이언트가 /api/trends 에서 가져온다.
 * 나라는 API 가 cf-ipcountry 로 판단하므로 여기서 넘길 것이 없다.
 */
export async function NewsPage({ searchParams }: { searchParams: Promise<{ kind?: string }> }) {
  const { kind } = await searchParams;
  return <NewsFeed initialKind={kind === 'video' ? 'video' : ('news' satisfies WireKind)} />;
}
