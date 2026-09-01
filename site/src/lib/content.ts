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
  kinds?: string[];
}

export const TABS: Tab[] = [
  { key: 'all', label: 'All' },
  { key: 'trends', label: 'Trends', kinds: ['report', 'inquiry', 'changelog', 'column', 'forecast'] },
  { key: 'studies', label: 'Studies', kinds: ['abstract'] },
  { key: 'exhibits', label: 'Exhibits', kinds: ['pick'] },
  { key: 'town', label: 'Town life', kinds: ['log', 'notice', 'verdict', 'obituary', 'apology'] },
  { key: 'humans', label: 'Humans', kinds: ['human'] },
];

export function kindLabel(kind: string): string {
  return KIND_LABEL[kind] ?? String(kind).toUpperCase();
}

export function kindsForTab(tabKey: string): string[] | null {
  return TABS.find((t) => t.key === tabKey)?.kinds ?? null;
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

export function youtubeThumb(id: string | null): string | null {
  return id && /^[\w-]{6,20}$/.test(id) ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : null;
}
