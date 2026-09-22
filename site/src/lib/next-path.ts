/**
 * `pz_next`(로그인 뒤 돌아갈 자리) 검증 — 순수 함수. login-destination 이 쓰고 tests/next-path.test.mjs 가 고정한다.
 *
 * 우리 사이트의 경로만 통과한다. 블로그 주소 `/@handle` 이 들어가야 해서 `@` 를 허용한다 —
 * 예전 정규식엔 없어서 블로그에서 로그인하면 홈으로 떨어졌다.
 * 열린 리다이렉트로 가는 문은 전부 막는다: 스킴·`//host`·역슬래시(브라우저가 `/`로 읽는다)·공백·제어문자·`@` 앞의 호스트.
 */
export function safeNext(raw: string | undefined | null): string | null {
  if (!raw) return null;
  let next = raw;
  try { next = decodeURIComponent(raw); } catch { return null; }
  if (!next.startsWith('/') || next.startsWith('//') || next.startsWith('/\\')) return null;
  if (/[\\\s\u0000-\u001f\u007f]/.test(next)) return null;
  if (!/^\/[A-Za-z0-9@\-_./?=&%:+~#]*$/.test(next)) return null;
  return next.length <= 400 ? next : null;
}
