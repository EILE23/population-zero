import { getCloudflareContext } from '@opennextjs/cloudflare';
import { postHref } from '@/lib/content';

/** population.town 존 — 비밀이 아니라 상수로 둔다 */
const ZONE_ID = 'ad96c14729f6558562751461a818849b';
const ORIGIN = 'https://population.town';
/** Cloudflare purge_cache 가 한 호출에 받는 최대 파일 수 */
const PURGE_CHUNK = 30;

/**
 * 엣지 캐시 퍼지 — 글을 지우거나 고친 뒤 그 주소가 한동안 옛 모습으로 남지 않게.
 *
 * "영구 삭제"라고 써 놓고 캐시가 몇 분 더 보여주면 거짓말이 된다. 토큰이 없으면 조용히 건너뛴다:
 * 퍼지는 보증이지 기능이 아니라, 실패해도 삭제 자체는 이미 끝나 있어야 한다.
 *
 * 워커(worker-entry.js)는 요청 URL 에 `_c=국가` 를 붙인 키로 저장한다. 그래서 지울 때도 같은 키를
 * 나라별로 만들어야 하고, 존 퍼지에도 그 변형을 그대로 넣어야 한다 — `_c` 없는 주소는 어디에도 저장돼 있지 않다.
 * 주소가 30개를 넘으면 잘라 버리지 않고 30개씩 나눠 끝까지 보낸다.
 */
export async function purgePaths(paths: string[]): Promise<void> {
  const files = [...new Set(paths)].filter(Boolean).map((p) => (p.startsWith('http') ? p : ORIGIN + p));
  if (!files.length) return;
  const keyed = files.flatMap((f) => WORKER_CACHE_COUNTRIES.map((c) => {
    const u = new URL(f); u.searchParams.set('_c', c); return u.toString();
  }));

  // 1) 이 데이터센터의 워커 캐시 — 같은 런타임이라 caches.default 를 바로 만질 수 있다.
  //    다른 데이터센터의 사본은 아래 존 퍼지가 맡는다.
  try {
    const store = (globalThis as { caches?: { default?: Cache } }).caches?.default;
    if (store) await Promise.all(keyed.map((u) => store.delete(new Request(u, { method: 'GET' })).catch(() => false)));
  } catch { /* 아래 존 퍼지로 넘어간다 */ }

  // 2) 존 엣지 캐시 — 토큰이 있을 때만. 실패해도 삭제·수정의 결과를 바꾸지 않는다.
  try {
    const { env } = await getCloudflareContext({ async: true });
    const token = env.CF_CACHE_PURGE_TOKEN;
    if (!token) return;
    for (let i = 0; i < keyed.length; i += PURGE_CHUNK) {
      const res = await fetch(`https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache`, {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ files: keyed.slice(i, i + PURGE_CHUNK) }),
      });
      if (!res.ok) console.error('cache purge failed', res.status, await res.text().catch(() => ''));
    }
  } catch (e) { console.error('cache purge error', e); }
}

/** 워커 캐시 키에 쓰이는 국가 코드 후보 — 뉴스 수집 대상 + 근처 큰 나라 + 미상 */
const WORKER_CACHE_COUNTRIES = ['XX', 'US', 'GB', 'KR', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG', 'CA', 'SG', 'VN', 'TW', 'PH'];

/**
 * 글 하나가 바뀌었을 때 옛 모습이 남아 있을 수 있는 주소들.
 * 실제 링크와 canonical 은 /p/id/슬러그 다 — /p/id 만 지우면 사람들이 실제로 연 주소는 남는다.
 * 제목을 고쳤다면 옛 슬러그 주소도 함께 넘긴다 (titles 에 이전·이후 제목을 모두).
 */
export function postPaths(postId: number, handle?: string | null, titles: (string | null | undefined)[] = []): string[] {
  const slugged = titles.filter((t): t is string => typeof t === 'string' && t.length > 0).map((t) => postHref(postId, t));
  return [`/p/${postId}`, ...slugged, '/', ...(handle ? [`/@${handle}`] : [])];
}
