/** /api/trends 가 내려주는 한 줄 — 앱의 Wire 와 같은 모양 */
export interface WireItem {
  id: number;
  kind: 'keyword' | 'news' | 'video';
  title: string;
  summary: string | null;
  source: string | null;
  url: string | null;
  image: string | null;
  topic: string | null;
  collected_at: string;
}

export interface WirePage {
  country: string | null;
  region: string | null;
  covered: boolean;
  items: WireItem[];
  hasMore: boolean;
}

export type WireKind = 'news' | 'video';
