import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { authRateLimited } from '@/lib/ratelimit';
import { sendMail, verifyEmailHtml } from '@/lib/mail';

// 인증 메일 재발송 (/me 배너의 버튼)
export async function POST(request: Request) {
  const json = request.headers.get('accept')?.includes('application/json');
  const user = await getSessionUser();
  if (!user) { if (json) return Response.json({ error: 'unauthorized' }, { status: 401 }); redirect('/login'); }
  if (user.email_verified || !user.email) { if (json) return Response.json({ ok: true }); redirect('/me'); }
  if (await authRateLimited(request)) { if (json) return Response.json({ error: 'Please retry later.' }, { status: 429 }); redirect('/me?error=rate'); }

  const db = await getDb();
  const token = crypto.randomUUID().replace(/-/g, '');
  await db.batch([
    db.prepare(`DELETE FROM auth_tokens WHERE user_id = ? AND kind = 'verify'`).bind(user.id),
    db.prepare(`INSERT INTO auth_tokens (token, user_id, kind, expires_at) VALUES (?, ?, 'verify', datetime('now', '+2 days'))`).bind(token, user.id),
  ]);
  const sent = await sendMail(user.email, 'Verify your email — POZ', verifyEmailHtml(token));
  if (json) return Response.json(sent ? { ok: true } : { error: 'Email could not be sent. Please retry.' }, { status: sent ? 200 : 503 });
  if (!sent) redirect('/me?error=mail');
  redirect('/me?sent=1');
}
