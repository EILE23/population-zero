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

export type BlockKind = 'intro' | 'banner' | 'posts' | 'guestbook' | 'text' | 'image' | 'links' | 'divider';
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
}

export interface BlogLayout {
  v: 1;
  /** 'stack' 한 기둥 · 'rail-left'/'rail-right' 두 기둥 */
  shell: 'stack' | 'rail-left' | 'rail-right';
  width: 'narrow' | 'normal' | 'wide';
  theme: Theme;
  blocks: Block[];
}

const HEX = /^#[0-9a-fA-F]{3,8}$/;
const ONE_OF = <T extends string>(v: unknown, allowed: readonly T[], fallback: T): T =>
  (allowed as readonly string[]).includes(String(v)) ? (v as T) : fallback;

export const DEFAULT_THEME: Theme = {
  bg: '#f7f5f6', ink: '#1B0C15', accent: '#AD7096',
  font: 'sans', radius: 'lg', density: 'normal', border: 'hairline', banner: 'none',
};

/** 아무것도 안 고른 블로그 — 지금 화면과 같은 모양이어야 한다(꾸미기 전과 후가 이어져야 하니까) */
export const DEFAULT_LAYOUT: BlogLayout = {
  v: 1,
  shell: 'stack',
  width: 'normal',
  theme: DEFAULT_THEME,
  blocks: [
    { id: 'intro', kind: 'intro' },
    { id: 'posts', kind: 'posts', props: { view: 'grid', columns: 3, cover: true, excerpt: true } },
    { id: 'guestbook', kind: 'guestbook' },
  ],
};

/** kind 마다 허용하는 설정과 기본값. 여기 없는 열쇠는 저장되지 않는다. */
const PROP_SPEC: Record<BlockKind, Record<string, { type: 'bool' | 'int' | 'text' | 'enum'; values?: readonly string[]; def: string | number | boolean; max?: number }>> = {
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
  guestbook: { title: { type: 'text', def: 'Guestbook', max: 60 } },
  text: { body: { type: 'text', def: '', max: 2000 }, align: { type: 'enum', values: ['left', 'center'], def: 'left' } },
  image: { src: { type: 'text', def: '', max: 400 }, caption: { type: 'text', def: '', max: 200 }, full: { type: 'bool', def: false } },
  links: { items: { type: 'text', def: '', max: 1200 } },  // 한 줄에 "제목|주소"
  divider: { style: { type: 'enum', values: ['line', 'dots', 'space'], def: 'line' } },
};

const KINDS = Object.keys(PROP_SPEC) as BlockKind[];
const MAX_BLOCKS = 20;

function cleanProps(kind: BlockKind, raw: unknown): Record<string, string | number | boolean> {
  const spec = PROP_SPEC[kind];
  const src = (raw ?? {}) as Record<string, unknown>;
  const out: Record<string, string | number | boolean> = {};
  for (const [key, s] of Object.entries(spec)) {
    const v = src[key];
    if (v === undefined) continue;
    if (s.type === 'bool') out[key] = v === true || v === 'true';
    else if (s.type === 'int') out[key] = Math.min(Math.max(Math.round(Number(v) || 1), 1), s.max ?? 3);
    else if (s.type === 'enum') out[key] = ONE_OF(v, s.values ?? [], String(s.def));
    else out[key] = String(v).slice(0, s.max ?? 200);
  }
  return out;
}

/** 저장 직전과 렌더 직전 모두 이 문을 지난다. 이상한 값은 튕기지 않고 기본값으로 접는다. */
export function cleanLayout(raw: unknown): BlogLayout {
  const src = (raw ?? {}) as Partial<BlogLayout> & { theme?: Partial<Theme>; blocks?: unknown };
  const t = (src.theme ?? {}) as Partial<Theme>;
  const blocks: Block[] = Array.isArray(src.blocks) ? (src.blocks as Block[]) : DEFAULT_LAYOUT.blocks;

  const seen = new Set<string>();
  const cleaned: Block[] = [];
  for (const b of blocks.slice(0, MAX_BLOCKS)) {
    const kind = KINDS.includes(b?.kind as BlockKind) ? (b.kind as BlockKind) : null;
    if (!kind) continue;
    // 글 목록과 방명록은 블로그의 기능이라 두 번 놓을 수 없다 — 꾸미다가 기능이 겹쳐 보이면 안 된다
    if ((kind === 'posts' || kind === 'guestbook' || kind === 'intro') && seen.has(kind)) continue;
    seen.add(kind);
    const id = String(b.id ?? kind).replace(/[^\w-]/g, '').slice(0, 24) || kind;
    cleaned.push({ id: cleaned.some((x) => x.id === id) ? `${id}-${cleaned.length}` : id, kind, rail: b.rail === true, props: cleanProps(kind, b.props) });
  }
  // 글 목록이 없으면 붙인다. 꾸미다가 글이 사라지면 그건 꾸민 게 아니다.
  if (!cleaned.some((b) => b.kind === 'posts')) cleaned.push({ id: 'posts', kind: 'posts', props: cleanProps('posts', { view: 'grid' }) });

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
    },
    blocks: cleaned,
  };
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
  };
}
