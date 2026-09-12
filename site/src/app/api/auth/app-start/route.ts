import { cookies } from 'next/headers';
export async function GET(request: Request) {
  const challenge = new URL(request.url).searchParams.get('challenge') ?? '';
  if (!/^[a-f0-9]{64}$/.test(challenge)) return new Response(null, { status: 400 });
  (await cookies()).set('pz_app_login', challenge, { httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge: 600 });
  return Response.redirect(new URL('/app-login', request.url), 303);
}
