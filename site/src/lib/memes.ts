/**
 * 짤 — 공통 규칙. API·페이지·순찰이 같은 문을 지난다.
 *
 * 바탕 그림은 정해진 곳의 주소만 통과한다(우리 보관함 + 밈 풀의 출처). 아무 주소나 받으면 방문자 아이피가 남의 서버로 샌다.
 * 결과 PNG 는 우리 보관함(pz-assets→jsDelivr)이어야 한다 — 우리가 올린 것만 우리 벽에 건다.
 * 글자와 스타일은 값으로만 받는다 — 문자열이 스타일 시트에 들어가는 일은 없다.
 */
export const ASSET_PREFIX = 'https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/';
/** 바탕으로 쓸 수 있는 그림의 출처 — 전부 CORS(*) 가 열려 있어 캔버스에서 toBlob 이 된다 (실측). 풀(meme_pool)을 채우는 스크립트와 같은 목록이어야 한다 */
export const PICTURE_HOSTS = [
  ASSET_PREFIX,
  'https://i.imgflip.com/',           // 지금 세계에서 제일 많이 쓰이는 밈 템플릿 100장 (imgflip 공개 API)
  'https://images.metmuseum.org/',    // 메트로폴리탄 미술관 퍼블릭 도메인 — 명화에 헛소리 얹기는 장르다
  'https://upload.wikimedia.org/',    // 위키미디어 공용
] as const;
export const TEXT_MAX = 120;
export const TEXTS_MAX = 8;

export interface MemeText {
  t: string;
  /** 0~1 — 그림 폭·높이에 대한 비율. 화면 크기가 달라도 같은 자리에 놓인다 */
  x: number; y: number;
  /** 그림 높이에 대한 비율 (0.05 = 높이의 5%) */
  size: number;
  color: string; stroke: string;
  /** 도 단위 */
  rot: number;
  /** 세계 밈의 네 글꼴 — Impact, Comic Sans, 매직펜, Times. 한 나라용 글꼴은 두지 않는다 */
  font: 'impact' | 'comic' | 'hand' | 'serif';
  /** 글자 뒤 — 없음 · 상자 · 말풍선(꼬리) · 뱃지(타원) */
  bg: 'none' | 'box' | 'bubble' | 'badge';
}

/** 세로로 쌓이는 컷. 각 컷은 자기 그림(또는 빈 흰 판)을 가진다 — "싫어→싫어→싫어!!!" 식 4컷 */
export const PANELS_MAX = 4;

export interface MemeStyle { texts: MemeText[]; panels: (string | null)[] }

const HEX = /^#[0-9a-fA-F]{3,8}$/;
const clamp = (n: unknown, lo: number, hi: number, def: number) => {
  const v = Number(n); return Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : def;
};

const sane = (url: unknown): url is string => typeof url === 'string' && !/[\s<>"']/.test(url) && url.length < 400;
/** 우리 보관함의 파일 — 결과 PNG·업로드는 여기여야 한다 */
export function isAsset(url: unknown): url is string {
  return sane(url) && url.startsWith(ASSET_PREFIX);
}
/** 바탕으로 쓸 수 있는 그림 — 보관함 또는 밈 풀의 출처 */
export function isPicture(url: unknown): url is string {
  return sane(url) && PICTURE_HOSTS.some((h) => url.startsWith(h));
}
export const FONTS = ['impact', 'comic', 'hand', 'serif'] as const;

/** 들어온 값은 전부 모르는 사람이 쓴 것으로 본다. 목록 밖 값은 기본값으로 접는다 */
export function cleanStyle(raw: unknown): MemeStyle {
  const src = (raw ?? {}) as { texts?: unknown; panels?: unknown };
  const rawPanels = Array.isArray(src.panels) ? src.panels : [];
  const panels = rawPanels.slice(0, PANELS_MAX).map((u) => (isPicture(u) ? u : null));
  const list = Array.isArray(src.texts) ? src.texts : [];
  const texts: MemeText[] = [];
  for (const t of list.slice(0, TEXTS_MAX)) {
    const o = (t ?? {}) as Partial<MemeText>;
    const text = String(o.t ?? '').replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '').slice(0, TEXT_MAX);
    if (!text.trim()) continue;
    texts.push({
      t: text,
      x: clamp(o.x, 0, 1, 0.5), y: clamp(o.y, 0, 1, 0.5),
      size: clamp(o.size, 0.02, 0.4, 0.09),
      color: HEX.test(String(o.color)) ? String(o.color) : '#ffffff',
      stroke: HEX.test(String(o.stroke)) ? String(o.stroke) : '#000000',
      rot: clamp(o.rot, -180, 180, 0),
      font: FONTS.includes(o.font as MemeText['font']) ? (o.font as MemeText['font']) : 'impact',
      bg: (['none', 'box', 'bubble', 'badge'] as const).includes(o.bg as MemeText['bg']) ? (o.bg as MemeText['bg']) : 'none',
    });
  }
  return { texts, panels: panels.length ? panels : [null] };
}

export const memeHref = (id: number) => `/m/${id}`;

/** 게시물 종류 — 만든/올린 그림, GIF, 유튜브 영상. 벽은 이 셋을 같은 카드로 보여 준다 */
export type MemeKind = 'image' | 'gif' | 'video';
export const kindOf = (png: string): MemeKind => (/\.gif$/i.test(png) ? 'gif' : 'image');

/** 유튜브 주소에서 영상 ID — watch?v= · youtu.be/ · shorts/ · embed/ 를 전부 받는다. 아니면 null */
export function youtubeId(raw: unknown): string | null {
  if (typeof raw !== 'string' || raw.length > 300) return null;
  const m = raw.trim().match(/^(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|embed\/|live\/)|youtu\.be\/)([\w-]{11})(?:[?&#]|$)/);
  return m ? m[1] : null;
}
export const youtubeThumb = (id: string) => `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
export const youtubeEmbed = (id: string) => `https://www.youtube-nocookie.com/embed/${id}`;
