/**
 * 블로그 배치 — 주인이 직접 옮기고 고르는 것들. CSS 가 아니라 값이다.
 *
 * 왜 CSS 를 안 쓰는가:
 *  ① 사람이 CSS 를 쓰게 하면 CSS 를 아는 사람만 꾸민다. 화면에서 끌어 옮기는 편집기를 만들려면
 *     저장되는 게 "블록 순서 + 고른 값"이어야 한다.
 *  ② 값이면 **우리 컴포넌트가 그린다** — 주입된 CSS 를 해석할 일이 없으니 깨질 자리가 없고,
 *     앱도 같은 값을 읽어 자기 방식으로 그릴 수 있다(CSS 는 앱이 따라올 수 없다).
 *  ③ 주민도 같은 JSON 을 쓴다. 주민에게만 열어주는 건 없다는 규칙이 저절로 지켜진다.
 *
 * 들어오는 값은 전부 모르는 사람이 쓴 것으로 취급한다 — 목록에 없는 값은 조용히 기본값으로 접는다.
 */

export type BlockKind = 'header' | 'intro' | 'banner' | 'posts' | 'toc' | 'guestbook' | 'memes' | 'text' | 'image' | 'links' | 'divider' | 'search' | 'actions' | 'chrome';
export type PostsView = 'grid' | 'list' | 'magazine' | 'index';
export type Columns = 1 | 2 | 3;

export interface Block {
  id: string;
  kind: BlockKind;
  /** 블록이 왼쪽 기둥에 들어가는지 — 2단 배치에서만 쓰인다 */
  rail?: boolean;
  /** kind 별 설정. 모르는 열쇠는 버린다 */
  props?: Record<string, string | number | boolean>;
}

export interface Theme {
  bg: string; ink: string; accent: string;
  font: 'sans' | 'serif' | 'mono' | 'display';
  radius: 'none' | 'sm' | 'lg' | 'pill';
  density: 'tight' | 'normal' | 'roomy';
  border: 'none' | 'hairline' | 'bold';
  banner: 'none' | 'band' | 'full';
  /** 글자 — 크기 배율·자간·행간 */
  scale: 'sm' | 'md' | 'lg';
  tracking: 'tight' | 'normal' | 'wide';
  leading: 'tight' | 'normal' | 'loose';
}

/** 헤더 띠에 놓을 수 있는 것들. account 는 빼지 못한다 — 로그아웃·내 페이지로 가는 유일한 문이다 */
export const CHROME_ITEMS = ['search', 'about', 'contact', 'bell', 'messages', 'write', 'account'] as const;
export type ChromeItem = typeof CHROME_ITEMS[number];

/** 사이트 띠 — 우리 것이지만 이 블로그에서 어떻게 보일지는 주인이 정한다 */
export interface Chrome {
  /** 홈으로 가는 표시: POZ 로고 · 내가 쓴 글자 · 안 보이기(푸터엔 그대로 남는다) */
  home: 'logo' | 'label' | 'none';
  label: string;
  /** 검색·알림·쓰기·계정이 있는 고정 띠의 자리. 'off' 는 그 띠를 아예 없애고 chrome 블록으로 대신한다 */
  nav: 'top' | 'bottom' | 'off';
  /** 그 띠에 무엇을 어떤 순서로 둘지. account 는 항상 포함된다 */
  items: ChromeItem[];
}

export interface BlogLayout {
  v: 1;
  /** 'stack' 한 기둥 · 'rail-left'/'rail-right' 두 기둥 */
  shell: 'stack' | 'rail-left' | 'rail-right';
  width: 'narrow' | 'normal' | 'wide';
  theme: Theme;
  chrome: Chrome;
  blocks: Block[];
}

const HEX = /^#[0-9a-fA-F]{3,8}$/;
const ONE_OF = <T extends string>(v: unknown, allowed: readonly T[], fallback: T): T =>
  (allowed as readonly string[]).includes(String(v)) ? (v as T) : fallback;

export const DEFAULT_THEME: Theme = {
  bg: '#f7f5f6', ink: '#1B0C15', accent: '#AD7096',
  font: 'sans', radius: 'lg', density: 'normal', border: 'hairline', banner: 'none',
  scale: 'md', tracking: 'normal', leading: 'normal',
};

/** 아무것도 안 고른 블로그 — 지금 화면과 같은 모양이어야 한다(꾸미기 전과 후가 이어져야 하니까) */
export const DEFAULT_CHROME: Chrome = { home: 'logo', label: '', nav: 'top', items: [...CHROME_ITEMS] };

export const DEFAULT_LAYOUT: BlogLayout = {
  v: 1,
  shell: 'stack',
  width: 'normal',
  theme: DEFAULT_THEME,
  chrome: DEFAULT_CHROME,
  blocks: [
    { id: 'header', kind: 'header' },
    { id: 'intro', kind: 'intro' },
    { id: 'posts', kind: 'posts', props: { view: 'grid', columns: 3, cover: true, excerpt: true } },
    { id: 'guestbook', kind: 'guestbook' },
  ],
};

/** kind 마다 허용하는 설정과 기본값. 여기 없는 열쇠는 저장되지 않는다. */
type PropSpec = { type: 'bool' | 'int' | 'text' | 'enum' | 'color'; values?: readonly string[]; def: string | number | boolean; max?: number };

/**
 * 모든 블록이 공통으로 가지는 것 — 위 간격, 안쪽 여백, 그리고 이 블록만의 배경·글자색.
 * 블록마다 따로 넣지 않는 이유: 하나를 추가할 때마다 열 군데를 고치게 되고, 그러면 곧 갈라진다.
 */
const COMMON_SPEC: Record<string, PropSpec> = {
  gap: { type: 'enum', values: ['none', 'sm', 'md', 'lg', 'xl'], def: 'md' },
  pad: { type: 'enum', values: ['none', 'sm', 'md', 'lg'], def: 'none' },
  bg: { type: 'color', def: '' },
  ink: { type: 'color', def: '' },
  // 한 줄에 여러 블록을 놓으려면 블록이 자기 폭을 알아야 한다 — 그룹 개념을 만들지 않고 폭으로 푼다
  span: { type: 'enum', values: ['full', 'half', 'third', 'two-thirds'], def: 'full' },
  place: { type: 'enum', values: ['start', 'center', 'end'], def: 'start' },
  edge: { type: 'enum', values: ['none', 'line', 'box', 'shadow'], def: 'none' },
  round: { type: 'enum', values: ['theme', 'none', 'sm', 'lg', 'pill'], def: 'theme' },
  // 글자 효과 — 다른 편집기에서 흔히 쓰는 것들. 값으로만 받는다
  shadow: { type: 'enum', values: ['none', 'soft', 'hard', 'glow'], def: 'none' },
  caps: { type: 'bool', def: false },
  weight: { type: 'enum', values: ['normal', 'bold', 'black'], def: 'normal' },
};

const PROP_SPEC: Record<BlockKind, Record<string, PropSpec>> = {
  // 블로그 머리 — 제목과 주인 줄. 사이트 띠(POZ·검색·계정)는 우리 것이라 여기 없다
  header: {
    size: { type: 'enum', values: ['sm', 'md', 'lg', 'xl'], def: 'lg' },
    align: { type: 'enum', values: ['left', 'center'], def: 'left' },
    fill: { type: 'enum', values: ['none', 'accent', 'ink', 'image'], def: 'none' },
    image: { type: 'text', def: '', max: 400 },
    rule: { type: 'enum', values: ['none', 'thin', 'thick'], def: 'thick' },
    show_handle: { type: 'bool', def: true },
    show_avatar: { type: 'bool', def: true },
    show_follows: { type: 'bool', def: true },
  },
  intro: {
    show_avatar: { type: 'bool', def: true },
    show_follows: { type: 'bool', def: true },
    align: { type: 'enum', values: ['left', 'center'], def: 'left' },
  },
  banner: {
    text: { type: 'text', def: '', max: 400 },
    image: { type: 'text', def: '', max: 400 },
    height: { type: 'enum', values: ['sm', 'md', 'lg'], def: 'md' },
    align: { type: 'enum', values: ['left', 'center'], def: 'left' },
  },
  posts: {
    view: { type: 'enum', values: ['grid', 'list', 'magazine', 'index'], def: 'grid' },
    columns: { type: 'int', def: 3, max: 3 },
    cover: { type: 'bool', def: true },
    excerpt: { type: 'bool', def: true },
    topics: { type: 'bool', def: true },
  },
  // 목차 — 사이드바에 넣으면 왼쪽 목차 정리가 된다(주제·연재·최근 글)
  toc: {
    title: { type: 'text', def: 'Contents', max: 40 },
    topics: { type: 'bool', def: true },
    series: { type: 'bool', def: true },
    recent: { type: 'int', def: 8, max: 20 },
  },
  guestbook: { title: { type: 'text', def: 'Guestbook', max: 60 } },
  // 이 사람이 벽(/memes)에 올린 짤·릴 — 블로그에도 걸린다
  memes: { title: { type: 'text', def: 'Shitposts', max: 40 }, limit: { type: 'int', def: 6, max: 12 } },
  text: { body: { type: 'text', def: '', max: 2000 }, align: { type: 'enum', values: ['left', 'center'], def: 'left' } },
  image: { src: { type: 'text', def: '', max: 400 }, caption: { type: 'text', def: '', max: 200 }, full: { type: 'bool', def: false } },
  links: { items: { type: 'text', def: '', max: 1200 } },  // 한 줄에 "제목|주소"
  divider: { style: { type: 'enum', values: ['line', 'dots', 'space'], def: 'line' } },
  // 사이트 띠에서 꺼내 쓸 수 있는 조각들 — 요소를 분해하는 게 아니라 블록으로 내놓는다
  search: { placeholder: { type: 'text', def: 'Search', max: 40 }, wide: { type: 'bool', def: false } },
  // 헤더 조각을 담는 블록 — 고정 띠를 끄고 이걸 원하는 자리(사이드바 포함)에 놓으면 그게 이 블로그의 헤더다
  chrome: {
    search: { type: 'bool', def: false },
    about: { type: 'bool', def: true },
    contact: { type: 'bool', def: true },
    bell: { type: 'bool', def: false },
    messages: { type: 'bool', def: true },
    write: { type: 'bool', def: true },
    account: { type: 'bool', def: true },
    dir: { type: 'enum', values: ['row', 'column'], def: 'row' },
    style: { type: 'enum', values: ['plain', 'buttons'], def: 'plain' },
  },
  actions: {
    write: { type: 'bool', def: true },
    messages: { type: 'bool', def: true },
    follow: { type: 'bool', def: true },
    style: { type: 'enum', values: ['button', 'link'], def: 'button' },
  },
};

const KINDS = Object.keys(PROP_SPEC) as BlockKind[];
const MAX_BLOCKS = 20;

/**
 * 필수 블록 — 지울 수 없고, 없으면 자동으로 붙는다.
 * 블로그의 기능이기 때문이다: 제목 없는 블로그, 글 목록 없는 블로그, 방명록 없는 블로그는 블로그가 아니다.
 * 자리·모양·색은 전부 주인이 정한다 — 있다는 것만 보장한다.
 */
export const REQUIRED: BlockKind[] = ['header', 'posts', 'guestbook'];

function cleanProps(kind: BlockKind, raw: unknown): Record<string, string | number | boolean> {
  const spec = { ...COMMON_SPEC, ...PROP_SPEC[kind] };
  const src = (raw ?? {}) as Record<string, unknown>;
  const out: Record<string, string | number | boolean> = {};
  for (const [key, s] of Object.entries(spec)) {
    const v = src[key];
    if (v === undefined) continue;
    if (s.type === 'bool') out[key] = v === true || v === 'true';
    else if (s.type === 'int') out[key] = Math.min(Math.max(Math.round(Number(v) || 1), 1), s.max ?? 3);
    else if (s.type === 'enum') out[key] = ONE_OF(v, s.values ?? [], String(s.def));
    else if (s.type === 'color') { const c = String(v); if (HEX.test(c)) out[key] = c; }  // 색은 #hex 만 통과한다
    else out[key] = String(v).slice(0, s.max ?? 200);
  }
  return out;
}

/** 저장 직전과 렌더 직전 모두 이 문을 지난다. 이상한 값은 튕기지 않고 기본값으로 접는다. */
export function cleanLayout(raw: unknown): BlogLayout {
  const src = (raw ?? {}) as Partial<BlogLayout> & { theme?: Partial<Theme>; chrome?: Partial<Chrome>; blocks?: unknown };
  const t = (src.theme ?? {}) as Partial<Theme>;
  const c = (src.chrome ?? {}) as Partial<Chrome>;
  const blocks: Block[] = Array.isArray(src.blocks) ? (src.blocks as Block[]) : DEFAULT_LAYOUT.blocks;

  const seen = new Set<string>();
  const cleaned: Block[] = [];
  for (const b of blocks.slice(0, MAX_BLOCKS)) {
    const kind = KINDS.includes(b?.kind as BlockKind) ? (b.kind as BlockKind) : null;
    if (!kind) continue;
    // 글 목록과 방명록은 블로그의 기능이라 두 번 놓을 수 없다 — 꾸미다가 기능이 겹쳐 보이면 안 된다
    if ((kind === 'posts' || kind === 'guestbook' || kind === 'intro' || kind === 'header') && seen.has(kind)) continue;
    seen.add(kind);
    const id = String(b.id ?? kind).replace(/[^\w-]/g, '').slice(0, 24) || kind;
    cleaned.push({ id: cleaned.some((x) => x.id === id) ? `${id}-${cleaned.length}` : id, kind, rail: b.rail === true, props: cleanProps(kind, b.props) });
  }
  // 필수 블록은 빠지면 되돌려 놓는다. 꾸미다가 기능이 사라지면 그건 꾸민 게 아니다.
  // (배치를 정한 블로그는 사이트 마스트헤드가 제목을 안 그리므로 header 가 빠지면 제목 없는 블로그가 된다)
  if (!cleaned.some((b) => b.kind === 'header')) cleaned.unshift({ id: 'header', kind: 'header', props: cleanProps('header', {}) });
  for (const kind of REQUIRED) {
    if (kind === 'header' || cleaned.some((b) => b.kind === kind)) continue;
    cleaned.push({ id: kind, kind, props: cleanProps(kind, kind === 'posts' ? { view: 'grid' } : {}) });
  }

  // 띠를 아예 꺼도 된다 — 로그아웃·내 자리로 가는 길은 푸터가 낸다
  const nav = ONE_OF(c.nav, ['top', 'bottom', 'off'] as const, DEFAULT_CHROME.nav);

  return {
    v: 1,
    shell: ONE_OF(src.shell, ['stack', 'rail-left', 'rail-right'] as const, 'stack'),
    width: ONE_OF(src.width, ['narrow', 'normal', 'wide'] as const, 'normal'),
    theme: {
      bg: HEX.test(String(t.bg)) ? String(t.bg) : DEFAULT_THEME.bg,
      ink: HEX.test(String(t.ink)) ? String(t.ink) : DEFAULT_THEME.ink,
      accent: HEX.test(String(t.accent)) ? String(t.accent) : DEFAULT_THEME.accent,
      font: ONE_OF(t.font, ['sans', 'serif', 'mono', 'display'] as const, DEFAULT_THEME.font),
      radius: ONE_OF(t.radius, ['none', 'sm', 'lg', 'pill'] as const, DEFAULT_THEME.radius),
      density: ONE_OF(t.density, ['tight', 'normal', 'roomy'] as const, DEFAULT_THEME.density),
      border: ONE_OF(t.border, ['none', 'hairline', 'bold'] as const, DEFAULT_THEME.border),
      banner: ONE_OF(t.banner, ['none', 'band', 'full'] as const, DEFAULT_THEME.banner),
      scale: ONE_OF(t.scale, ['sm', 'md', 'lg'] as const, DEFAULT_THEME.scale),
      tracking: ONE_OF(t.tracking, ['tight', 'normal', 'wide'] as const, DEFAULT_THEME.tracking),
      leading: ONE_OF(t.leading, ['tight', 'normal', 'loose'] as const, DEFAULT_THEME.leading),
    },
    chrome: {
      home: ONE_OF(c.home, ['logo', 'label', 'none'] as const, DEFAULT_CHROME.home),
      label: String(c.label ?? '').replace(/\s+/g, ' ').trim().slice(0, 24),
      nav,
      items: cleanItems(c.items),
    },
    blocks: cleaned,
  };
}

/**
 * 목록 밖 값은 버리고 중복은 접는다.
 * 계정 메뉴는 빼도 된다 — 로그아웃과 내 자리로 가는 길은 푸터가 보장한다(features/layout/Footer.tsx).
 */
function cleanItems(raw: unknown): ChromeItem[] {
  const src = Array.isArray(raw) ? raw : DEFAULT_CHROME.items;
  const out: ChromeItem[] = [];
  for (const v of src) {
    const item = String(v) as ChromeItem;
    if ((CHROME_ITEMS as readonly string[]).includes(item) && !out.includes(item)) out.push(item);
  }
  return out;
}

export function parseLayout(json: string | null | undefined): BlogLayout {
  if (!json) return DEFAULT_LAYOUT;
  try { return cleanLayout(JSON.parse(json)); } catch { return DEFAULT_LAYOUT; }
}

// ── 값 → 실제 스타일 ────────────────────────────────────────────────────────────
// 고른 값만 CSS 변수로 내보낸다. 주인이 쓴 문자열이 스타일 시트에 들어가는 일은 없다(색은 #hex 검증 통과분뿐).

const FONTS: Record<Theme['font'], string> = {
  sans: "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Malgun Gothic',sans-serif",
  serif: "Newsreader,Georgia,'Times New Roman',serif",
  mono: 'ui-monospace,SFMono-Regular,Menlo,Consolas,monospace',
  display: "Newsreader,Georgia,serif",
};
const RADII: Record<Theme['radius'], string> = { none: '0', sm: '4px', lg: '12px', pill: '999px' };
const GAPS: Record<Theme['density'], string> = { tight: '0.75rem', normal: '1.5rem', roomy: '2.5rem' };
const BORDERS: Record<Theme['border'], string> = { none: '0', hairline: '1px', bold: '2px' };
export const WIDTHS: Record<BlogLayout['width'], string> = { narrow: '46rem', normal: '72rem', wide: '82rem' };

/** 한 줄에 여러 블록 — 폭 비율 */
export const BLOCK_SPAN: Record<string, string> = { full: '100%', half: 'calc(50% - var(--pz-gap) / 2)', third: 'calc(33.333% - var(--pz-gap) * 2 / 3)', 'two-thirds': 'calc(66.666% - var(--pz-gap) / 3)' };

/** 블록 간격과 안쪽 여백 — 고른 값만 크기로 번역한다(문자열이 스타일로 새지 않는다) */
export const BLOCK_GAP: Record<string, string> = { none: '0', sm: '0.6rem', md: 'var(--pz-gap)', lg: '3rem', xl: '5rem' };
export const BLOCK_PAD: Record<string, string> = { none: '0', sm: '0.75rem', md: '1.25rem', lg: '2rem' };

/** 스킨 변수 — 값에서만 만들어지므로 주입 위험이 없다 */
export function themeVars(t: Theme): Record<string, string> {
  return {
    '--pz-bg': t.bg,
    '--pz-ink': t.ink,
    '--pz-accent': t.accent,
    '--pz-font': FONTS[t.font],
    '--pz-radius': RADII[t.radius],
    '--pz-gap': GAPS[t.density],
    '--pz-border': BORDERS[t.border],
    '--pz-scale': { sm: '0.92', md: '1', lg: '1.12' }[t.scale],
    '--pz-tracking': { tight: '-0.015em', normal: '0', wide: '0.04em' }[t.tracking],
    '--pz-leading': { tight: '1.35', normal: '1.6', loose: '1.85' }[t.leading],
  };
}
