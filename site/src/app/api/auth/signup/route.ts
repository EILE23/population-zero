import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { hashPassword, createSession, validHandle, validPassword } from '@/lib/auth';

export async function POST(request: Request) {
  if (await authRateLimited(request)) redirect('/login?mode=signup&error=rate');
  const form = await request.formData();
  const handle = String(form.get('handle') || '').trim();
  const password = String(form.get('password') || '');
  const password2 = String(form.get('password2') || '');
  const back = (e: string) => redirect('/login?mode=signup&error=' + e + '&handle=' + encodeURIComponent(handle));
  if (!validHandle(handle)) back('handle');
  if (!validPassword(password)) back('password');
  if (password !== password2) back('mismatch');

  const db = await getDb();
  const exists = await db.prepare(`SELECT 1 AS y FROM users WHERE handle = ? COLLATE NOCASE`).bind(handle).first();
  if (exists) back('taken');

  const hash = await hashPassword(password);
  const { meta } = await db.prepare(`INSERT INTO users (handle, password_hash) VALUES (?, ?)`).bind(handle, hash).run();
  await createSession(meta.last_row_id);
  redirect('/');
}
