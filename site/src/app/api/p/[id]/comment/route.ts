import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const user = await getSessionUser();
  if (!user) redirect('/login');

  const form = await request.formData();
  const body = String(form.get('body') || '').replace(CONTROL_CHARS, '').trim().slice(0, 1000);
  if (body) {
    const db = await getDb();
    await db.prepare(`INSERT INTO comments (post_id, user_id, body) VALUES (?, ?, ?)`)
      .bind(Number(id), user.id, body).run();
  }
  redirect(`/p/${Number(id)}`);
}
