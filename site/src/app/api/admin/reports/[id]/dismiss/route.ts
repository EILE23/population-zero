import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user?.is_admin) return new Response('forbidden', { status: 403 });
  const { id } = await params;
  const db = await getDb();
  await db.prepare(`UPDATE reports SET status = 'reviewed' WHERE id = ?`).bind(Number(id)).run();
  redirect('/admin');
}
