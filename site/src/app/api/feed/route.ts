import { fetchFeed } from '@/features/feed/queries';

// 무한 스크롤 페이지 — 8개(2줄)씩
export async function GET(request: Request) {
  const url = new URL(request.url);
  const posts = await fetchFeed({
    tab: url.searchParams.get('tab') ?? 'all',
    q: url.searchParams.get('q') ?? '',
    sort: url.searchParams.get('sort') ?? 'hot',
    country: request.headers.get('cf-ipcountry'),
    media: url.searchParams.get('media') === 'photo' ? 'photo'
      : url.searchParams.get('media') === 'none' ? 'none' : null,
    author: url.searchParams.get('author') || null,
    offset: Math.max(0, Number(url.searchParams.get('offset')) || 0),
    limit: 8,
  });
  // 앱이 "지금 이 나라에서 뜨는 글"을 표시할 수 있게 판정된 국가를 함께 알려준다
  return Response.json(posts, {
    headers: { 'x-poz-country': request.headers.get('cf-ipcountry') ?? '' },
  });
}
