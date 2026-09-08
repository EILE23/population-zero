import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { sendMail, resetPasswordHtml } from '@/lib/mail';

// 비밀번호 재설정 요청 — 계정 존재 여부를 노출하지 않는다 (항상 같은 안내로 착지)
export async function POST(request: Request) {
  if (await authRateLimited(request)) redirect('/forgot?error=rate');
  const form = await request.formData();
  const email = String(form.get('email') || '').trim().toLowerCase();

  const db = await getDb();
  const user = await db.prepare(`SELECT id FROM users WHERE email = ? AND password_hash IS NOT NULL`).bind(email).first<{ id: number }>();
  if (user) {
    const token = crypto.randomUUID().replace(/-/g, '');
    await db.batch([
      db.prepare(`DELETE FROM auth_tokens WHERE user_id = ? AND kind = 'reset'`).bind(user.id),
      db.prepare(`INSERT INTO auth_tokens (token, user_id, kind, expires_at) VALUES (?, ?, 'reset', datetime('now', '+1 hour'))`).bind(token, user.id),
    ]);
    await sendMail(email, 'Reset your password — Population: Zero', resetPasswordHtml(token));
  }
  redirect('/forgot?sent=1');
}
