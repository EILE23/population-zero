import { getCloudflareContext } from '@opennextjs/cloudflare';

/** population.town 존 — 비밀이 아니라 상수로 둔다 */
const ZONE_ID = 'ad96c14729f6558562751461a818849b';
const ORIGIN = 'https://population.town';

/**
 * 엣지 캐시 퍼지 — 글을 지우거나 고친 뒤 그 주소가 한동안 옛 모습으로 남지 않게.
 *
 * "영구 삭제"라고 써 놓고 캐시가 몇 분 더 보여주면 거짓말이 된다. 토큰이 없으면 조용히 건너뛴다:
 * 퍼지는 보증이지 기능이 아니라, 실패해도 삭제 자체는 이미 끝나 있어야 한다.
 */
export async function purgePaths(paths: string[]): Promise<void> {
  const files = [...new Set(paths)].filter(Boolean).map((p) => (p.startsWith('http') ? p : ORIGIN + p)).slice(0, 30);
  if (!files.length) return;

  // 1) 워커 자체 캐시(worker-entry.js) — 키가 `?_c=국가` 라 나라별로 하나씩 지운다.
  //    같은 런타임이라 caches.default 를 바로 만질 수 있다. 목록 밖 나라는 60초 TTL 로 알아서 빠진다.
  try {
    const store = (globalThis as { caches?: { default?: Cache } }).caches?.default;
    if (store) {
      await Promise.all(files.flatMap((f) => WORKER_CACHE_COUNTRIES.map((c) => {
        const u = new URL(f); u.searchParams.set('_c', c);
        return store.delete(new Request(u.toString(), { method: 'GET' })).catch(() => false);
      })));
    }
  } catch { /* 아래 존 퍼지로 넘어간다 */ }

  // 2) 존 엣지 캐시 — 토큰이 있을 때만
  try {
    const { env } = await getCloudflareContext({ async: true });
    const token = env.CF_CACHE_PURGE_TOKEN;
    if (!token) return;
    await fetch(`https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ files }),
    });
  } catch { /* 퍼지 실패는 삭제·수정의 결과를 바꾸지 않는다 */ }
}

/** 워커 캐시 키에 쓰이는 국가 코드 후보 — 뉴스 수집 대상 + 근처 큰 나라 + 미상 */
const WORKER_CACHE_COUNTRIES = ['XX', 'US', 'GB', 'KR', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG', 'CA', 'SG', 'VN', 'TW', 'PH'];

/** 글 하나가 바뀌었을 때 옛 모습이 남아 있을 수 있는 주소들 */
export function postPaths(postId: number, handle?: string | null): string[] {
  return [`/p/${postId}`, '/', ...(handle ? [`/@${handle}`] : [])];
}
