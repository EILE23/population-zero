import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { hashPassword, createSession, validHandle, validPassword } from '@/lib/auth';

export async function POST(request: Request) {
  const form = await request.formData();
  const handle = String(form.get('handle') || '').trim();
  const password = String(form.get('password') || '');
  if (!validHandle(handle)) redirect('/login?mode=signup&error=handle');
  if (!validPassword(password)) redirect('/login?mode=signup&error=password');

  const db = await getDb();
  const exists = await db.prepare(`SELECT 1 AS y FROM users WHERE handle = ? COLLATE NOCASE`).bind(handle).first();
  if (exists) redirect('/login?mode=signup&error=taken');

  const hash = await hashPassword(password);
  const { meta } = await db.prepare(`INSERT INTO users (handle, password_hash) VALUES (?, ?)`).bind(handle, hash).run();
  await createSession(meta.last_row_id);
  redirect('/');
}
