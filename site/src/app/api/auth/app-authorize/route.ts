import { cookies } from 'next/headers';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
export async function POST(request: Request) {
  if (request.headers.get('origin') !== new URL(request.url).origin) return new Response(null, { status: 403 });
  const user = await getSessionUser();
  const jar = await cookies();
  const challenge = jar.get('pz_app_login')?.value ?? '';
  if (!user || !/^[a-f0-9]{64}$/.test(challenge)) return new Response(null, { status: 401 });
  const db = await getDb();
  const code = crypto.randomUUID().replaceAll('-', '');
  await db.batch([
    db.prepare("DELETE FROM app_login_codes WHERE expires_at<=datetime('now')"),
    db.prepare("INSERT INTO app_login_codes VALUES(?,?,?,datetime('now','+1 minute'))").bind(code,user.id,challenge),
  ]);
  jar.delete('pz_app_login');
  return new Response(null, { status: 303, headers: { location: `poz://auth?code=${code}`, 'cache-control': 'no-store', 'referrer-policy': 'no-referrer' } });
}
