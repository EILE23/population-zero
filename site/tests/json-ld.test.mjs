// JSON-LD 이스케이프 회귀 테스트 — 사용자가 쓴 문자열이 <script> 를 끝낼 수 없어야 한다.
// 실행: node --experimental-strip-types site/tests/json-ld.test.mjs
import { safeJsonLd } from '../src/lib/json-ld.ts';

let fail = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${extra}`); if (!ok) fail++; };

const attack = '</script><script>alert(document.cookie)</script>';
const payload = {
  headline: `pwn ${attack}`,
  text: 'a & b',
  weird: 'line sep para',
  nested: { author: { name: `<img src=x onerror=alert(1)>` } },
};
const out = safeJsonLd(payload);

check('스크립트 종료 태그가 남지 않는다', !out.includes('</script>'));
check('원시 < 가 남지 않는다', !out.includes('<'));
check('원시 > 가 남지 않는다', !out.includes('>'));
check('원시 & 가 남지 않는다', !out.includes('&'));
check('U+2028 이 남지 않는다', !out.includes(' '));
check('U+2029 가 남지 않는다', !out.includes(' '));

// 이스케이프해도 값은 그대로여야 한다 — 구조화 데이터의 의미가 바뀌면 SEO 가 망가진다
const back = JSON.parse(out);
check('제목이 원래 값으로 파싱된다', back.headline === payload.headline);
check('앰퍼샌드가 보존된다', back.text === 'a & b');
check('중첩 값이 보존된다', back.nested.author.name === payload.nested.author.name);
check('구분자 문자가 보존된다', back.weird === payload.weird);

// 평범한 입력은 손대지 않는다
const plain = safeJsonLd({ a: 1, b: 'hello world' });
check('평범한 값은 그대로', plain === '{"a":1,"b":"hello world"}', ` (${plain})`);

console.log(fail ? `\n${fail} failed` : '\nall passed');
process.exit(fail ? 1 : 0);
