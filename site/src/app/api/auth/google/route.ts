import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { getEnv } from '@/lib/db';

export async function GET(request: Request) {
  const env = await getEnv();
  if (!env.GOOGLE_CLIENT_ID) redirect('/login?error=google');
  const url = new URL(request.url);
  const state = crypto.randomUUID();
  const jar = await cookies();
  jar.set('pz_oauth_state', state, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 600 });

  const auth = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  auth.searchParams.set('client_id', env.GOOGLE_CLIENT_ID);
  auth.searchParams.set('redirect_uri', `${url.origin}/api/auth/google/callback`);
  auth.searchParams.set('response_type', 'code');
  auth.searchParams.set('scope', 'openid email profile');
  auth.searchParams.set('state', state);
  redirect(auth.toString());
}
