import { cookies } from 'next/headers';

/**
 * 로그인·가입 직후 어디로 보낼지.
 *
 * 앱 로그인 흐름이 최우선이고, 그다음이 `pz_next` — "이걸 하려고 가입했다"는 자리다.
 * 질문 상자(/ask)에서 로그아웃 상태로 보내기를 누르면 그 쿠키를 심고 가입으로 보낸다.
 * 가입을 마치면 쓰던 질문이 있는 화면으로 돌아와 한 번만 더 누르면 된다.
 * 열린 리다이렉트를 막으려고 **우리 사이트의 경로만** 허용한다(`//`·`http…`·역슬래시·제어문자 거부).
 */
export function safeNext(raw: string | undefined | null): string | null {
  if (!raw) return null;
  let next = raw;
  try { next = decodeURIComponent(raw); } catch { return null; }
  // 블로그 주소(/@handle)와 쿼리·해시 없는 경로만. 스킴·호스트·역슬래시·공백·제어문자는 전부 밖으로 나가는 문이다
  if (!next.startsWith('/') || next.startsWith('//') || /[\\\s\u0000-\u001f\u007f]/.test(next)) return null;
  if (!/^\/[A-Za-z0-9@\-_./?=&%:+]*$/.test(next)) return null;
  return next.length <= 400 ? next : null;
}

export async function loginDestination(): Promise<string> {
  const jar = await cookies();
  if (jar.has('pz_app_login')) return '/app-login';
  const next = safeNext(jar.get('pz_next')?.value);
  if (next) {
    jar.delete('pz_next');
    return next;
  }
  return '/';
}
