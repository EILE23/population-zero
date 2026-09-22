// pz_next 검증 — 블로그 주소는 통과하고, 밖으로 나가는 문은 전부 막힌다.
// node --experimental-strip-types site/tests/next-path.test.mjs
import assert from 'node:assert/strict';
import { safeNext } from '../src/lib/next-path.ts';

const ok = (v) => assert.equal(safeNext(v), v, `should pass: ${v}`);
const no = (v) => assert.equal(safeNext(v), null, `should reject: ${String(v)}`);

// 우리 경로
ok('/');
ok('/@ireneshin');
ok('/@iris_kr/series/one');
ok('/p/318');
ok('/ask?seed=1&x=2');
ok('/p/318#c-12');
ok('/write?title=first+post');
assert.equal(safeNext('%2F%40ireneshin'), '/@ireneshin'); // 쿠키에 인코딩돼 들어온 값

// 열린 리다이렉트
no(undefined); no(null); no('');
no('https://evil.test/');
no('//evil.test/');
no('/\\evil.test');
no('\\\\evil.test');
no('/%5Cevil.test'); // 디코드하면 역슬래시
no('/ p');
no('/p/318\n');
no('/p/318\u0000');
no('javascript:alert(1)');
no('%ZZ'); // 깨진 인코딩
no('/' + 'a'.repeat(400));

// 콜론은 경로 안에서 무해하다(`/p/1:2`), 스킴이 될 수 없다 — 문자열이 `/` 로 시작하므로
ok('/p/1:2');

console.log('PASS: next-path');
