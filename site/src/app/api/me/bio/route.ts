import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  const form = await request.formData();
  const bio = String(form.get('bio') || '').replace(CONTROL_CHARS, '').trim().slice(0, 300);
  const blogTitle = String(form.get('blog_title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 60);
  const db = await getDb();
  await db.prepare(`UPDATE users SET bio = ?, blog_title = ? WHERE id = ?`).bind(bio, blogTitle || null, user.id).run();
  redirect('/me');
}
