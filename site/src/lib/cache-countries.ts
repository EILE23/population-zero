/**
 * 워커 캐시 키에 쓰는 국가 코드 — 저장하는 쪽(worker-entry.js)과 지우는 쪽(lib/cache.ts)이 같은 목록을 본다.
 * 저장할 때는 아무 두 글자나 받고 지울 때는 18개만 만들면, PL·NL·IR 방문자의 사본은 영영 지워지지 않았다.
 * 목록 밖 나라는 'XX' 로 접는다: 피드 가중치가 없는 나라라 같은 화면을 보므로 사본을 나눌 이유도 없다.
 */
export const CACHE_COUNTRIES = ['XX', 'US', 'GB', 'KR', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG', 'CA', 'SG', 'VN', 'TW', 'PH'] as const;

const KNOWN = new Set<string>(CACHE_COUNTRIES);

/** 요청 헤더의 국가를 캐시 키용 코드로 — 목록에 없으면 'XX' */
export function cacheCountryOf(header: string | null | undefined): string {
  const c = (header || 'XX').toUpperCase();
  return KNOWN.has(c) ? c : 'XX';
}
