import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { getDb, getEnv } from '@/lib/db';
import { createSession } from '@/lib/auth';

// 구글 프로필 이름 → 마을 핸들 후보로 정규화, 충돌 시 숫자 접미
async function uniqueHandle(db: D1Database, base: string) {
  let handle = base.replace(/[^A-Za-z0-9_-]/g, '').slice(0, 16) || 'human';
  if (handle.length < 3) handle = `human_${handle}`;
  for (let i = 0; i < 50; i++) {
    const candidate = i === 0 ? handle : `${handle}${i + 1}`;
    const exists = await db.prepare(`SELECT 1 AS y FROM users WHERE handle = ? COLLATE NOCASE`).bind(candidate).first();
    if (!exists) return candidate;
  }
  return `human_${Date.now()}`;
}

export async function GET(request: Request) {
  const env = await getEnv();
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const jar = await cookies();
  const savedState = jar.get('pz_oauth_state')?.value;
  jar.delete('pz_oauth_state');
  if (!code || !state || state !== savedState) redirect('/login?error=google');

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: env.GOOGLE_CLIENT_ID ?? '',
      client_secret: env.GOOGLE_CLIENT_SECRET ?? '',
      redirect_uri: `${url.origin}/api/auth/google/callback`,
      grant_type: 'authorization_code',
    }),
  });
  if (!tokenRes.ok) redirect('/login?error=google');
  const { access_token } = await tokenRes.json() as { access_token: string };

  const profileRes = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
    headers: { authorization: `Bearer ${access_token}` },
  });
  if (!profileRes.ok) redirect('/login?error=google');
  const profile = await profileRes.json() as { sub: string; email?: string; name?: string };

  const db = await getDb();
  let user = await db.prepare(`SELECT id FROM users WHERE google_sub = ?`).bind(profile.sub).first<{ id: number }>();
  if (!user) {
    const handle = await uniqueHandle(db, profile.name || profile.email?.split('@')[0] || 'human');
    const { meta } = await db.prepare(`INSERT INTO users (handle, email, google_sub) VALUES (?, ?, ?)`)
      .bind(handle, profile.email ?? null, profile.sub).run();
    user = { id: meta.last_row_id };
  }
  await createSession(user.id);
  redirect('/');
}
