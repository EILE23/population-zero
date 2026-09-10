// 출처 게이트 — 사실형 글이 이번 실행에서 읽은 출처를 달았는지 검사한다.
// "없는 사실을 쓰지 말라"는 최우선 규칙이 코드로 확인되는 유일한 지점이므로 회귀를 막는다.
import { checkSources, collectedUrls } from '../source-gate.mjs';

let fail = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${extra}`); if (!ok) fail++; };
const one = (post, collected = new Set()) => checkSources([post], collected).problems;

const TRENDS = { items: [{ url: 'https://www.bbc.com/news/articles/abc123' }, { url: 'https://arstechnica.com/gadgets/2026/09/thing/' }] };
const collected = collectedUrls(TRENDS);

check('trends URL 수집', collected.size === 2, ` (${collected.size})`);

// ── 통과해야 하는 것 ──
check('개인 이야기 글 (factual_claims: false)', one({ title: 'lost my keys again', kind: 'post', factual_claims: false, body: 'no links here' }).length === 0);
check('소설은 검사 대상 아님', one({ title: 'chapter 3', kind: 'fiction' }).length === 0);
check('사실형 + 수집 출처 + 본문 노출', one({
  title: 'the ruling explained', kind: 'report', factual_claims: true,
  sources: ['https://www.bbc.com/news/articles/abc123'],
  body: 'source: https://www.bbc.com/news/articles/abc123',
}, collected).length === 0);
check('sources 를 객체로 줘도 인정', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: [{ url: 'https://arstechnica.com/gadgets/2026/09/thing/', title: 't' }],
  media_type: 'link', media_ref: 'https://arstechnica.com/gadgets/2026/09/thing/',
}, collected).length === 0);
check('같은 매체의 다른 기사도 인정 (호스트 일치)', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: ['https://www.bbc.com/news/articles/zzz999'],
  og_from: 'https://www.bbc.com/news/articles/zzz999',
}, collected).length === 0);
check('수집물이 없으면(light 순찰) 출처 대조는 건너뜀', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: ['https://example.com/a'], body: 'https://example.com/a',
}).length === 0);

// ── 걸러야 하는 것 ──
check('factual_claims 미표기', one({ title: 'x', kind: 'report', body: 'y' }).some((p) => p.includes('factual_claims 미표기')));
check('사실형인데 출처 없음', one({ title: 'x', kind: 'report', factual_claims: true, body: 'trust me' }).some((p) => p.includes('sources 없음')));
check('http 출처는 인정 안 함', one({ title: 'x', kind: 'report', factual_claims: true, sources: ['http://insecure.example/a'], body: 'a' }).some((p) => p.includes('sources 없음')));
check('출처가 독자에게 안 보임', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: ['https://www.bbc.com/news/articles/abc123'], body: '링크 없는 본문',
}, collected).some((p) => p.includes('보이지 않음')));
check('이번 실행과 무관한 출처(지어낸 링크)', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: ['https://totally-made-up-outlet.example/story'],
  body: 'https://totally-made-up-outlet.example/story',
}, collected).some((p) => p.includes('무관')));

// ── 집계 ──
const many = checkSources([
  { title: 'a', kind: 'fiction' },
  { title: 'b', kind: 'post', factual_claims: false },
  { title: 'c', kind: 'report', factual_claims: true },
], collected);
check('fiction 은 checked 에서 제외', many.checked === 2, ` (checked=${many.checked})`);
check('문제 있는 글만 보고', many.problems.length === 1, ` (${many.problems.length})`);

console.log(fail ? `\n${fail} failed` : '\nall passed');
process.exit(fail ? 1 : 0);
