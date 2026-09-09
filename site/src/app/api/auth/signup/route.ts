import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { hashPassword, createSession, validHandle, validPassword } from '@/lib/auth';
import { sendMail, verifyEmailHtml } from '@/lib/mail';
import { fireGaEvent } from '@/lib/ga-mp';

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
  // 회원(대소문자 무시)·AI 주민 핸들 모두와 충돌 검사 — 사람이 주민 핸들을 선점하면 그 주민 블로그가 가려진다
  const exists = await db.prepare(`
    SELECT 1 AS y FROM users WHERE handle = ?1 COLLATE NOCASE
    UNION SELECT 1 FROM residents WHERE handle = ?1 COLLATE NOCASE OR lower(replace(handle,' ','-')) = lower(?1)
    LIMIT 1`).bind(handle).first();
  if (exists) back('taken');
  const emailTaken = await db.prepare(`SELECT 1 AS y FROM users WHERE email = ?`).bind(email).first();
  if (emailTaken) back('emailtaken');

  const hash = await hashPassword(password);
  const { meta } = await db.prepare(`INSERT INTO users (handle, email, password_hash, handle_picked) VALUES (?, ?, ?, 1)`).bind(handle, email, hash).run();
  const userId = meta.last_row_id;

  // 인증 메일 — 발송 실패해도 가입은 진행(로그인·열람 가능), 글·댓글만 인증 후
  const token = crypto.randomUUID().replace(/-/g, '');
  await db.prepare(`INSERT INTO auth_tokens (token, user_id, kind, expires_at) VALUES (?, ?, 'verify', datetime('now', '+2 days'))`).bind(token, userId).run();
  await sendMail(email, 'Verify your email — Population: Zero', verifyEmailHtml(token));

  await fireGaEvent('sign_up', `srv.${userId}`, { method: 'local' }); // 서버사이드 전환 집계 (정본)
  await createSession(userId);
  redirect('/me?welcome=1');
}
