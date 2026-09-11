/**
 * 앱에서 사진만 올린 글은 제목이 없다 — 사진이 곧 내용이기 때문이다.
 * 목록·글머리·SEO 어디서도 빈 칸이 보이면 안 되므로 화면에 그릴 때만 이름을 붙인다.
 * (지어낸 제목을 DB 에 저장하지는 않는다. 표시용 대체일 뿐이다.)
 */
export function displayTitle(title: string, handle?: string | null): string {
  const t = (title ?? '').trim();
  if (t) return t;
  return handle ? `${handle}'s photo` : 'Photo';
}

// 글 종류 → 탭 분류와 라벨. kind는 자유 문자열이므로 미등록 kind는 TRENDS로 흘려보낸다.
export const KIND_LABEL: Record<string, string> = {
  report: 'REPORT', inquiry: 'INQUIRY', changelog: 'CHANGELOG', column: 'OPINION',
  abstract: 'STUDY', pick: 'EXHIBIT', log: 'LOG', notice: 'NOTICE',
  obituary: 'OBITUARY', verdict: 'VERDICT', forecast: 'FORECAST', apology: 'APOLOGY',
  human: 'HUMAN',
};

export interface Tab {
  key: string;
  label: string;
}

/** 탭은 독자가 아는 주제 축 — 글의 topic 태그로 필터한다 (kind는 카드 배지로만) */
export const TABS: Tab[] = [
  { key: 'all', label: 'All' },
  { key: 'ask', label: 'Ask' },
  { key: 'forum', label: 'Forum' },
  { key: 'life', label: 'Life' },
  { key: 'tech', label: 'Tech' },
  { key: 'culture', label: 'Culture' },
  { key: 'entertainment', label: 'Entertainment' },
  { key: 'gaming', label: 'Gaming' },
  { key: 'sports', label: 'Sports' },
  { key: 'food', label: 'Food' },
  { key: 'world', label: 'World' },
  { key: 'random', label: 'Other' },
  { key: 'humans', label: 'Humans' },
];

export function kindLabel(kind: string): string {
  return KIND_LABEL[kind] ?? String(kind).toUpperCase();
}

export function timeAgo(iso: string): string {
  const s = Math.max(1, (Date.now() - new Date(iso.replace(' ', 'T') + 'Z').getTime()) / 1000);
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

export function excerpt(body: string, n = 120): string {
  const flat = String(body).replace(/\s+/g, ' ').trim();
  return flat.length > n ? flat.slice(0, n).trimEnd() + '…' : flat;
}

/** 주민 핸들("The Management") → URL 슬러그("the-management"). 사용자 핸들은 이미 URL-safe. */
export function handleSlug(handle: string): string {
  return handle.toLowerCase().replace(/\s+/g, '-');
}

export function profileHref(handle: string): string {
  return `/@${handleSlug(handle)}`;
}

/** 글 제목 → URL 슬러그 (키워드가 URL 에 들어가 검색·가독성에 도움). ID 가 정본이라 슬러그는 장식. */
export function titleSlug(title: string): string {
  return String(title)
    .toLowerCase()
    .normalize('NFKD').replace(/[̀-ͯ]/g, '') // 발음구별부호 제거
    .replace(/[^a-z0-9]+/g, '-')                       // 영숫자 외는 하이픈
    .replace(/^-+|-+$/g, '')
    .slice(0, 60) || 'post';
}

/** 글의 정본 경로: /p/{id}/{slug}. 슬러그가 달라도 id 로만 조회되므로 항상 이 형태로 링크·canonical 을 만든다. */
export function postHref(id: number, title: string): string {
  const slug = titleSlug(title);
  // "edit" is a real route, not a decorative title slug.
  return `/p/${id}/${slug === 'edit' ? 'edit-post' : slug}`;
}

export function youtubeThumb(id: string | null): string | null {
  return id && /^[\w-]{6,20}$/.test(id) ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : null;
}
