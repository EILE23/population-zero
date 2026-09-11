// 출처 게이트 — 사실형 글이 이번 실행에서 실제로 읽은 출처를 달았는지 검사한다.
// "없는 사실을 쓰지 말라"는 최우선 규칙이 코드로 확인되는 유일한 지점이라 회귀를 막는다.
// 검사는 일부러 정확 일치다 — 같은 매체면 통과로 두면 실재하지 않는 기사 URL 을 못 잡는다.
import { checkSources, collectedUrls, normalizeUrl } from '../source-gate.mjs';

let fail = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${extra}`); if (!ok) fail++; };
const one = (post, collected = new Set(), opts) => checkSources([post], collected, opts).problems;

const BBC = 'https://www.bbc.com/news/articles/abc123';
const ARS = 'https://arstechnica.com/gadgets/2026/09/thing/';
const collected = collectedUrls({ items: [{ url: BBC }, { url: ARS }] });

check('trends URL 수집', collected.size === 2, ` (${collected.size})`);

// ── URL 정규화 ──
check('www·끝슬래시 차이를 흡수', normalizeUrl('https://www.bbc.com/news/articles/abc123/') === normalizeUrl(BBC));
check('추적 파라미터를 무시', normalizeUrl(`${BBC}?utm_source=x&fbclid=y`) === normalizeUrl(BBC));
check('앵커를 무시', normalizeUrl(`${BBC}#section2`) === normalizeUrl(BBC));
check('다른 기사는 다르게 본다', normalizeUrl('https://www.bbc.com/news/articles/zzz999') !== normalizeUrl(BBC));

// ── 통과해야 하는 것 ──
check('개인 이야기 글 (factual_claims: false)', one({ title: 'lost my keys again', kind: 'post', factual_claims: false, body: 'no links' }).length === 0);
check('소설은 검사 대상 아님', one({ title: 'chapter 3', kind: 'fiction' }).length === 0);
check('사실형 + 수집 출처 + 본문 노출', one({
  title: 'the ruling explained', kind: 'report', factual_claims: true,
  sources: [BBC], body: `source: ${BBC}`,
}, collected).length === 0);
check('sources 를 객체로 줘도 인정', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: [{ url: ARS, title: 't' }], media_type: 'link', media_ref: ARS,
}, collected).length === 0);
// og_from 은 커버 이미지를 뽑는 입력일 뿐 글에 렌더되지 않는다 — 독자 노출로 치지 않는다
check('og_from 만으로는 노출 인정 안 함', one({
  title: 'x', kind: 'report', factual_claims: true, sources: [BBC], og_from: BBC,
}, collected).some((p) => p.includes('보이지 않음')));
check('추적 파라미터가 붙어도 같은 출처로 인정', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: [`${BBC}?utm_source=newsletter`], body: `read: ${BBC}`,
}, collected).length === 0);

// ── 걸러야 하는 것 ──
check('factual_claims 미표기', one({ title: 'x', kind: 'report', body: 'y' }).some((p) => p.includes('boolean 이 아님')));
// ── 2026-09-11 리뷰 R06 재현 케이스 ──
check('문자열 "true" 는 사실 선언으로 안 침', one({
  title: 'x', kind: 'report', factual_claims: 'true', sources: [BBC], body: BBC,
}, collected).some((p) => p.includes('boolean 이 아님')));
check('숫자 1 도 안 침', one({ title: 'x', kind: 'report', factual_claims: 1 }, collected).some((p) => p.includes('boolean 이 아님')));
check('수집한 출처와 보이는 출처가 다르면 거부', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: [BBC, 'https://unseen-outlet.example/story'],
  body: 'read this: https://unseen-outlet.example/story',
}, collected).some((p) => p.includes('수집분에 없음') || p.includes('서로 다름')));
check('같은 URL 이 수집·노출 모두 만족하면 통과', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: [BBC, 'https://unseen-outlet.example/story'],
  body: `both: ${BBC} and https://unseen-outlet.example/story`,
}, collected).length === 0);
check('사실형인데 출처 없음', one({ title: 'x', kind: 'report', factual_claims: true, body: 'trust me' }).some((p) => p.includes('sources 없음')));
check('http 출처는 인정 안 함', one({ title: 'x', kind: 'report', factual_claims: true, sources: ['http://insecure.example/a'], body: 'a' }).some((p) => p.includes('sources 없음')));
check('출처가 독자에게 안 보임', one({
  title: 'x', kind: 'report', factual_claims: true, sources: [BBC], body: '링크 없는 본문',
}, collected).some((p) => p.includes('보이지 않음')));
check('본문에 다른 링크만 있으면 노출로 안 쳐준다', one({
  title: 'x', kind: 'report', factual_claims: true, sources: [BBC], body: `see ${ARS}`,
}, collected).some((p) => p.includes('보이지 않음')));
check('같은 매체의 다른 기사는 수집분으로 인정 안 함', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: ['https://www.bbc.com/news/articles/zzz999'], body: 'https://www.bbc.com/news/articles/zzz999',
}, collected).some((p) => p.includes('수집분에 없음')));
check('지어낸 매체', one({
  title: 'x', kind: 'report', factual_claims: true,
  sources: ['https://totally-made-up.example/story'], body: 'https://totally-made-up.example/story',
}, collected).some((p) => p.includes('수집분에 없음')));
check('수집 증거 자체가 없으면 사실형 글 거부', one({
  title: 'x', kind: 'report', factual_claims: true, sources: [BBC], body: BBC,
}, new Set(), { requireCollected: true }).some((p) => p.includes('수집 증거가 없어')));

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
