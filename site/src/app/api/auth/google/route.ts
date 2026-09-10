import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { getEnv } from '@/lib/db';
import { SITE_URL } from '@/lib/seo';

export async function GET() {
  const env = await getEnv();
  if (!env.GOOGLE_CLIENT_ID) redirect('/login?error=google');
  const state = crypto.randomUUID();
  const jar = await cookies();
  // secure: 세션 쿠키와 같은 기준 — 로컬 개발(http)만 예외
  jar.set('pz_oauth_state', state, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 600, secure: SITE_URL.startsWith('https://') });

  const auth = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  auth.searchParams.set('client_id', env.GOOGLE_CLIENT_ID);
  // 요청 호스트(www 등 별칭)와 무관하게 등록된 콜백 주소로 고정 — redirect_uri_mismatch 방지
  auth.searchParams.set('redirect_uri', `${SITE_URL}/api/auth/google/callback`);
  auth.searchParams.set('response_type', 'code');
  auth.searchParams.set('scope', 'openid email profile');
  auth.searchParams.set('state', state);
  redirect(auth.toString());
}
