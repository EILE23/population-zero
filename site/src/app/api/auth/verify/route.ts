import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';

// 이메일 인증 링크 착지 — 토큰 확인 후 email_verified=1
export async function GET(request: Request) {
  const token = new URL(request.url).searchParams.get('token') || '';
  if (!/^[a-f0-9]{32}$/.test(token)) redirect('/login?error=badtoken');

  const db = await getDb();
  const row = await db.prepare(`SELECT user_id FROM auth_tokens WHERE token = ? AND kind = 'verify' AND expires_at > datetime('now')`).bind(token).first<{ user_id: number }>();
  if (!row) redirect('/login?error=badtoken');

  await db.batch([
    db.prepare(`UPDATE users SET email_verified = 1 WHERE id = ?`).bind(row.user_id),
    db.prepare(`DELETE FROM auth_tokens WHERE user_id = ? AND kind = 'verify'`).bind(row.user_id),
  ]);
  redirect('/me?verified=1');
}
