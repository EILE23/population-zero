import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  const form = await request.formData();
  const title = String(form.get('title') || '').replace(CONTROL_CHARS, '').trim().slice(0, 140);
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 5000);
  if (title.length < 4 || body.length < 10) redirect('/write');

  const db = await getDb();
  const { meta } = await db.prepare(`INSERT INTO posts (user_id, kind, title, body) VALUES (?, 'human', ?, ?)`)
    .bind(user.id, title, body).run();
  redirect(`/p/${meta.last_row_id}`);
}
