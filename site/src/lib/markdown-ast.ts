/**
 * POZ 마크다운 — 글 본문(posts.body)이 쓰는 **작은 부분집합**의 파서. 순수 함수만, 의존성 없음.
 *
 * 웹(site/src/lib/markdown.tsx)과 앱(app/src/ui/MarkdownBody.tsx)이 이 파서의 결과(블록 트리)를 각자 그린다.
 * 파서가 하나라야 같은 글이 웹과 앱에서 같은 구조로 보인다 — 예전엔 앱이 범용 파서(marked)를 써서
 * 웹엔 없는 표·HTML 이 앱에만 그려지고, 웹의 유튜브 임베드·줄바꿈이 앱에선 사라졌다.
 * 앱 사본: app/src/markdown-ast.ts — 글자 하나까지 같아야 하며 site/tests/app-parity.test.mjs 가 대조한다.
 *
 * 지원: # ## ###, **굵게**, *기울임*, `코드`, ``` 코드블록, > 인용, -/1. 목록(2칸 들여쓰기로 중첩),
 *       [텍스트](https://), ![alt](https://이미지), 줄 하나에 유튜브 URL 만 → 임베드, 맨몸 https:// 주소 → 링크,
 *       한 줄바꿈 = 줄바꿈, 빈 줄 = 문단.
 * 미지원(양쪽 다 그리지 않는다 — PATROL.md 와 apply.mjs 게이트가 막는다): 표, HTML, ####, ~~취소선~~, --- 구분선, _기울임_.
 */

export type Inline =
  | { t: 'text'; v: string }
  | { t: 'img'; src: string; alt: string }
  | { t: 'link'; href: string; text: string }
  | { t: 'code'; v: string }
  | { t: 'strong'; v: string }
  | { t: 'em'; v: string };

export type ListItem = { text: string; children: ListBlock | null };
export type ListBlock = { type: 'list'; ordered: boolean; items: ListItem[] };
export type Block =
  | { type: 'heading'; level: 1 | 2 | 3; text: string; id: string }
  | { type: 'paragraph'; text: string }
  | ListBlock
  | { type: 'code'; text: string }
  | { type: 'quote'; text: string }
  | { type: 'youtube'; id: string };

export type Heading = { level: number; text: string; id: string };

export const YOUTUBE_LINE = /^https:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([\w-]{6,20})\S*$/;

/** 헤딩 텍스트 → 앵커 id. 목차 링크와 본문 헤딩이 같은 규칙을 써야 점프가 맞는다. */
export function headingId(text: string, index: number): string {
  const base = String(text)
    .replace(/[*`_[\]()]/g, '')
    .trim().toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^\p{L}\p{N}-]/gu, '')
    .slice(0, 50);
  return `h-${index}${base ? '-' + base : ''}`; // index 를 앞에 둬 제목이 겹쳐도 중복되지 않는다
}

/** 인라인 토큰화 — 이미지 → 링크 → 코드 → 굵게 → 기울임 → 맨몸 URL 순서 */
const INLINE = /(!\[([^\]]*)\]\((https:\/\/[^\s)]+)\))|(\[([^\]]+)\]\((https:\/\/[^\s)]+)\))|(`([^`]+)`)|(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|((?:^|(?<=[\s(]))https:\/\/[^\s<>)]+)/g;

export function parseInline(text: string): Inline[] {
  const out: Inline[] = [];
  let last = 0; let m: RegExpExecArray | null;
  INLINE.lastIndex = 0;
  while ((m = INLINE.exec(text))) {
    if (m.index > last) out.push({ t: 'text', v: text.slice(last, m.index) });
    if (m[1]) out.push({ t: 'img', src: m[3], alt: m[2] });
    else if (m[4]) out.push({ t: 'link', href: m[6], text: m[5] });
    else if (m[7]) out.push({ t: 'code', v: m[8] });
    else if (m[9]) out.push({ t: 'strong', v: m[10] });
    else if (m[11]) out.push({ t: 'em', v: m[12] });
    else if (m[13]) {
      // 문장 끝의 마침표·쉼표는 주소가 아니다
      const url = m[13].replace(/[.,;:!?]+$/, '');
      out.push({ t: 'link', href: url, text: url });
      if (url.length < m[13].length) out.push({ t: 'text', v: m[13].slice(url.length) });
    }
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push({ t: 'text', v: text.slice(last) });
  return out;
}

export function parseMarkdown(text: string): Block[] {
  const lines = String(text).split('\n');
  const blocks: Block[] = [];
  let para: string[] = [];
  let list: ListBlock | null = null;
  let code: string[] | null = null;
  let quote: string[] = [];
  let headingIdx = 0;

  const flushPara = () => { if (para.length) { blocks.push({ type: 'paragraph', text: para.join('\n') }); para = []; } };
  const flushList = () => { if (list) { blocks.push(list); list = null; } };
  const flushQuote = () => { if (quote.length) { blocks.push({ type: 'quote', text: quote.join('\n') }); quote = []; } };
  const flushAll = () => { flushPara(); flushList(); flushQuote(); };

  for (const raw of lines) {
    const line = raw.replace(/\s+$/, '');
    if (code !== null) {
      if (line.trim() === '```') { blocks.push({ type: 'code', text: code.join('\n') }); code = null; }
      else code.push(raw);
      continue;
    }
    if (line.trim().startsWith('```')) { flushAll(); code = []; continue; }
    const h = line.match(/^(#{1,3})(?:\s+(.*))?$/);
    if (h) {
      flushAll();
      const clean = (h[2] ?? '').replace(/[*`]/g, '').trim();
      blocks.push({ type: 'heading', level: h[1].length as 1 | 2 | 3, text: h[2] ?? '', id: headingId(clean, headingIdx++) });
      continue;
    }
    const yt = line.trim().match(YOUTUBE_LINE);
    if (yt) { flushAll(); blocks.push({ type: 'youtube', id: yt[1] }); continue; }
    if (line.startsWith('> ')) { flushPara(); flushList(); quote.push(line.slice(2)); continue; }
    // 들여쓴 목록도 받는다: "  - 중첩", "\t- 중첩" (탭=2칸). depth 는 2칸당 1단계.
    const li = line.match(/^([ \t]*)(?:[-*]|(\d+)[.)])\s+(.*)$/);
    if (li) {
      flushPara(); flushQuote();
      const depth = Math.floor(li[1].replace(/\t/g, '  ').length / 2);
      const ordered = li[2] !== undefined;
      if (!list) list = { type: 'list', ordered, items: [] };
      let node: ListBlock = list;
      for (let d = 0; d < depth; d++) {
        const last = node.items[node.items.length - 1];
        if (!last) break; // 부모 없이 들여쓰기부터 시작한 경우 — 현재 단계에 그대로 붙인다
        if (!last.children) last.children = { type: 'list', ordered, items: [] };
        node = last.children;
      }
      node.items.push({ text: li[3] ?? '', children: null });
      continue;
    }
    if (line.trim() === '') { flushAll(); continue; }
    flushList(); flushQuote();
    para.push(line);
  }
  flushAll();
  if (code !== null) blocks.push({ type: 'code', text: code.join('\n') });
  return blocks;
}

/** 본문에서 목차용 헤딩 목록을 뽑는다 (코드블록 안의 # 는 제외). */
export function extractHeadings(text: string): Heading[] {
  const out: Heading[] = [];
  for (const b of parseMarkdown(text)) {
    if (b.type === 'heading') out.push({ level: b.level, text: b.text.replace(/[*`]/g, '').trim(), id: b.id });
  }
  return out;
}

/** 피드 발췌용 — 마크다운 기호 제거 */
export function stripMarkdown(text: string): string {
  return String(text)
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/^#{1,3}\s+/gm, '')
    .replace(/^>\s?/gm, '')
    .replace(/^\s*[-*]\s+/gm, '')
    .replace(/[*`]/g, '');
}

/**
 * 이 부분집합 밖의 문법 — 웹도 앱도 그리지 않으므로 글에 들어가면 안 된다.
 * 순찰 적용기(apply.mjs)와 같은 규칙: 표, HTML 태그, 4단계 이상 헤딩, 취소선, 구분선.
 * 코드블록 안은 보지 않는다. 결과는 사람이 읽을 문제 목록(비어 있으면 통과).
 */
export function unsupportedMarkdown(text: string): string[] {
  const problems: string[] = [];
  let inCode = false;
  String(text).split('\n').forEach((raw, i) => {
    const line = raw.replace(/\s+$/, '');
    if (line.trim().startsWith('```')) { inCode = !inCode; return; }
    if (inCode) return;
    const n = i + 1;
    if (/^\s*\|?\s*:?-{3,}:?\s*\|/.test(line) || /\|\s*:?-{3,}:?\s*\|?\s*$/.test(line)) problems.push(`line ${n}: table (not rendered) — write it as a list`);
    else if (/<\/?[a-zA-Z][^>]*>/.test(line)) problems.push(`line ${n}: HTML tag (not rendered) — use Markdown`);
    else if (/^#{4,}\s/.test(line)) problems.push(`line ${n}: heading deeper than ### (not rendered)`);
    else if (/~~\S[^~]*\S~~/.test(line)) problems.push(`line ${n}: ~~strikethrough~~ (not rendered)`);
    else if (/^\s*([-*_])\1{2,}\s*$/.test(line)) problems.push(`line ${n}: horizontal rule (not rendered) — use a blank line`);
  });
  return problems;
}
