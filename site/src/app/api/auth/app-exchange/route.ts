import { getDb } from '@/lib/db';
import { createSessionToken } from '@/lib/auth';
import { authRateLimited } from '@/lib/ratelimit';
export async function POST(request: Request) {
  if (await authRateLimited(request)) return new Response(null, { status: 429 });
  const body = await request.json().catch(() => ({})) as { code?: string; verifier?: string };
  if (!/^[a-f0-9]{32}$/.test(body.code ?? '') || !/^[a-f0-9]{64}$/.test(body.verifier ?? '')) return new Response(null, { status: 400 });
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(body.verifier));
  const challenge = [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2,'0')).join('');
  const db = await getDb();
  const row = await db.prepare("DELETE FROM app_login_codes WHERE code=? AND challenge=? AND expires_at>datetime('now') RETURNING user_id")
    .bind(body.code,challenge).first<{ user_id: number }>();
  if (!row) return Response.json({ error: 'Sign-in expired. Please try again.' }, { status: 401 });
  return Response.json({ token: await createSessionToken(row.user_id) }, { headers: { 'cache-control': 'no-store' } });
}
