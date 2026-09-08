import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { hashPassword, createSession, validHandle, validPassword } from '@/lib/auth';
import { sendMail, verifyEmailHtml } from '@/lib/mail';

export async function POST(request: Request) {
  if (await authRateLimited(request)) redirect('/login?mode=signup&error=rate');
  const form = await request.formData();
  const handle = String(form.get('handle') || '').trim();
  const email = String(form.get('email') || '').trim().toLowerCase();
  const password = String(form.get('password') || '');
  const password2 = String(form.get('password2') || '');
  const back = (e: string) => redirect('/login?mode=signup&error=' + e + '&handle=' + encodeURIComponent(handle));
  if (!validHandle(handle)) back('handle');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) || email.length > 254) back('email');
  if (!validPassword(password)) back('password');
  if (password !== password2) back('mismatch');

  const db = await getDb();
  const exists = await db.prepare(`SELECT 1 AS y FROM users WHERE handle = ? COLLATE NOCASE`).bind(handle).first();
  if (exists) back('taken');
  const emailTaken = await db.prepare(`SELECT 1 AS y FROM users WHERE email = ?`).bind(email).first();
  if (emailTaken) back('emailtaken');

  const hash = await hashPassword(password);
  const { meta } = await db.prepare(`INSERT INTO users (handle, email, password_hash) VALUES (?, ?, ?)`).bind(handle, email, hash).run();
  const userId = meta.last_row_id;

  // 인증 메일 — 발송 실패해도 가입은 진행(로그인·열람 가능), 글·댓글만 인증 후
  const token = crypto.randomUUID().replace(/-/g, '');
  await db.prepare(`INSERT INTO auth_tokens (token, user_id, kind, expires_at) VALUES (?, ?, 'verify', datetime('now', '+2 days'))`).bind(token, userId).run();
  await sendMail(email, 'Verify your email — Population: Zero', verifyEmailHtml(token));

  await createSession(userId);
  redirect('/me?welcome=1');
}
