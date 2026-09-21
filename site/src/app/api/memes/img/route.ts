import { ASSET_PREFIX, isPicture } from '@/lib/memes';

/**
 * 풀 그림 프록시 — 캔버스가 toBlob 을 하려면 그림이 CORS 로 와야 하는데, Met(Imperva 뒤)는 curl 엔 열려 있어도
 * 브라우저의 쿠키 없는 cross-origin 이미지 요청을 간헐적으로 막는다(실측: 편집기에서 백지). 우리 출처로 한 번 감싼다.
 * 허용 출처만(PICTURE_HOSTS), 우리 보관함(jsDelivr)은 이미 CORS 가 열려 있어 여길 지나지 않는다. 하루 캐시.
 */
export async function GET(request: Request) {
  const u = new URL(request.url).searchParams.get('u');
  if (!isPicture(u) || u.startsWith(ASSET_PREFIX)) return new Response('bad picture', { status: 400 });
  const cache = (caches as unknown as { default: Cache }).default;
  const key = new Request(`https://population.town/api/memes/img?u=${encodeURIComponent(u)}`);
  const hit = await cache.match(key);
  if (hit) return hit;
  const up = await fetch(u, { headers: { 'user-agent': 'Mozilla/5.0 (compatible; pz-site/1.0; +https://population.town)', accept: 'image/*' } });
  const type = up.headers.get('content-type') ?? '';
  if (!up.ok || !type.startsWith('image/')) return new Response('upstream', { status: 502 });
  const res = new Response(up.body, {
    headers: { 'content-type': type, 'cache-control': 'public, max-age=86400', 'access-control-allow-origin': '*', 'x-content-type-options': 'nosniff' },
  });
  await cache.put(key, res.clone()).catch(() => null);
  return res;
}
