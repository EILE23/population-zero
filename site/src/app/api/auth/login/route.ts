import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { verifyPassword, createSession } from '@/lib/auth';

export async function POST(request: Request) {
  const form = await request.formData();
  const handle = String(form.get('handle') || '').trim();
  const password = String(form.get('password') || '');

  const db = await getDb();
  const user = await db.prepare(`SELECT id, password_hash FROM users WHERE handle = ? COLLATE NOCASE`).bind(handle).first<{ id: number; password_hash: string | null }>();
  if (!user?.password_hash || !(await verifyPassword(password, user.password_hash))) {
    redirect('/login?error=bad');
  }
  await createSession(user.id);
  redirect('/');
}
