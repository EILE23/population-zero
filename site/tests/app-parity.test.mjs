// 앱과 웹이 '같은 값을 내야 하는' 규칙들을 같은 입력으로 돌려 대조한다.
// 한쪽만 고치면 여기서 잡힌다 — 주석("양쪽을 같이 고친다")이 유일한 계약이던 것을 테스트로 바꾼 것.
//   · 대화 실 열쇠 threadKey        app/src/rules.ts  ↔ site/src/lib/dm.ts
//   · 아바타 스타일·배경색            app/src/rules.ts  ↔ site/src/lib/avatar.ts
//   · 커뮤니티 주제 탭               app/src/rules.ts  ↔ site/src/lib/content.ts
//   · 브랜드 색 토큰                 app/src/theme.ts  ↔ site/src/design/tokens.css
// 저장소 루트에서: node --experimental-strip-types site/tests/app-parity.test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const app = await import('../../app/src/rules.ts');
const dm = await import('../src/lib/dm.ts');
const avatar = await import('../src/lib/avatar.ts');
const content = await import('../src/lib/content.ts');
const { theme } = await import('../../app/src/theme.ts');

const handles = ['rules_lawyer_ryan', 'eile_23', 'The Management', 'seoul_2호선', 'a', 'well_actually', 'x'.repeat(20), 'Émile', 'user 42'];

// 실 열쇠 — 순서를 바꿔 넣어도 같은 열쇠, 앱과 웹이 같은 열쇠
const parties = [{ kind: 'user', id: 7 }, { kind: 'resident', id: 13 }, { kind: 'user', id: 12 }, { kind: 'resident', id: 0 }];
for (const a of parties) for (const b of parties) {
  if (a.kind === b.kind && a.id === b.id) continue;
  assert.equal(app.threadKey(a, b), dm.threadKey(a, b), `threadKey ${JSON.stringify([a, b])}`);
  assert.equal(app.threadKey(a, b), app.threadKey(b, a));
}
console.log('PASS threadKey: app == web');

// 아바타 — 스타일·배경색(사람/주민)
for (const h of handles) {
  assert.equal(app.avatarStyleFor(h), avatar.avatarStyleFor(h), `style ${h}`);
  assert.equal(app.avatarBg(h, true), avatar.avatarBg(h, true), `bg human ${h}`);
  assert.equal(app.avatarBg(h, false), avatar.avatarBg(h, false), `bg resident ${h}`);
  assert.equal(app.avatarHue(h), avatar.avatarHue(h));
}
assert.deepEqual([...app.AVATAR_STYLES], [...avatar.AVATAR_STYLES]);
console.log('PASS avatar: style, background, hue identical');

// 주제 탭 — 키와 순서
assert.deepEqual(app.TOPIC_TABS.map((t) => t.key), content.TABS.map((t) => t.key), 'topic tab keys/order');
console.log('PASS topic tabs: same keys in the same order');

// 색 토큰 — 앱 theme.ts 가 tokens.css 를 거울처럼 들고 있어야 한다
const css = readFileSync(new URL('../src/design/tokens.css', import.meta.url), 'utf8');
const token = (name) => css.match(new RegExp(`--${name}:\\s*(#[0-9a-fA-F]{6})`))?.[1]?.toLowerCase();
const pairs = [['accent', theme.color.accent], ['accent-deep', theme.color.accentDeep], ['ink-900', theme.color.inkStrong], ['ink-800', theme.color.ink], ['ink-black', theme.color.inkBlack], ['paper', theme.color.paper], ['surface', theme.color.surface], ['surface-deep', theme.color.surfaceDeep], ['hairline', theme.color.hairline]];
for (const [name, appValue] of pairs) {
  assert.ok(token(name), `tokens.css has --${name}`);
  assert.equal(String(appValue).toLowerCase(), token(name), `color token ${name}`);
}
console.log('PASS colour tokens: app theme mirrors tokens.css');

// 마크다운 파서 — 같은 본문이 같은 블록 트리가 되어야 웹과 앱이 같은 글을 보여준다
const webMd = await import('../src/lib/markdown-ast.ts');
const appMd = await import('../../app/src/markdown-ast.ts');
const fixtures = [
  '# Title\n\nplain **bold** *em* `code` [link](https://a.b/c) and https://bare.example/path, then.\nsecond line same paragraph\n\nnew paragraph',
  '## Section one\n- item\n  - nested\n- item two\n1. first\n2. second\n\n> quoted\n> lines\n\n```\ncode # not heading\n```\n![alt](https://img.example/x.png)',
  'https://www.youtube.com/watch?v=dQw4w9WgXcQ\nafter video\n\nhttps://youtu.be/abc123def45?t=10',
  '#### too deep\n| a | b |\n|---|---|\n~~gone~~ <b>html</b>\n---',
  '',
  '   \n\n\n',
  'trailing spaces   \n\ttab-indented\n\t- tab list\n    - four spaces',
];
for (const f of fixtures) {
  assert.deepEqual(appMd.parseMarkdown(f), webMd.parseMarkdown(f), `parseMarkdown ${JSON.stringify(f.slice(0, 30))}`);
  assert.deepEqual(appMd.extractHeadings(f), webMd.extractHeadings(f));
  assert.equal(appMd.stripMarkdown(f), webMd.stripMarkdown(f));
  assert.deepEqual(appMd.unsupportedMarkdown(f), webMd.unsupportedMarkdown(f));
}
// 부분집합 밖의 문법은 잡히고, 안의 문법은 잡히지 않는다
assert.equal(webMd.unsupportedMarkdown(fixtures[3]).length, 4, 'h4, table separator, html (one per line), hr'); // 표 헤더 줄은 구분선 줄에서 잡힌다
assert.deepEqual(webMd.unsupportedMarkdown(fixtures[1]), []);
assert.deepEqual(webMd.unsupportedMarkdown('```\n| in | code |\n|---|---|\n```'), [], 'code blocks are not inspected');
// 웹의 임베드 줄이 앱에서도 같은 블록이다
assert.deepEqual(webMd.parseMarkdown(fixtures[2]).map((b) => b.type), ['youtube', 'paragraph', 'youtube']);
console.log('PASS markdown: same block tree, same headings, same excerpt, same unsupported list');
