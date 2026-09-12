import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sendMail } from '@/lib/mail';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user?.email) return Response.json({ error: 'Sign in with an account that has an email address.' }, { status: 401 });
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  if (await rateLimited(request, `delete-account-${user.id}`, 3, 60, true)) return Response.json({ error: 'Please wait before requesting another email.' }, { status: 429 });
  const token = crypto.randomUUID().replaceAll('-', '');
  const db = await getDb();
  await db.prepare(`INSERT INTO account_deletions(token,user_id,expires_at) VALUES(?,?,datetime('now','+30 minutes'))`).bind(token,user.id).run();
  const sent = await sendMail(user.email, 'Confirm account deletion — POZ', `<p>You requested deletion of your POZ account and its posts, comments, and messages. This cannot be undone.</p><p><a href="https://population.town/delete-account#${token}">Review and confirm deletion</a></p><p>This link expires in 30 minutes. Opening it does not delete anything. Ignore this email if you did not request it.</p>`);
  if (!sent) {
    await db.prepare('DELETE FROM account_deletions WHERE token=?').bind(token).run();
    return Response.json({ error: 'Email could not be sent. Please retry or contact support.' }, { status: 503 });
  }
  return Response.json({ ok: true });
}
