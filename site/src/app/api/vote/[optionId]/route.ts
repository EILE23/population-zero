import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ optionId: string }> }) {
  const { optionId } = await params;
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login' }, { status: 401 });

  const db = await getDb();
  const opt = await db.prepare(`SELECT id, post_id FROM poll_options WHERE id = ?`).bind(Number(optionId)).first();
  if (!opt) return Response.json({ error: 'not found' }, { status: 404 });

  const already = await db.prepare(`SELECT 1 AS y FROM poll_votes WHERE user_id = ? AND post_id = ?`).bind(user.id, opt.post_id).first();
  if (!already) {
    await db.batch([
      db.prepare(`INSERT INTO poll_votes (user_id, post_id, option_id) VALUES (?, ?, ?)`).bind(user.id, opt.post_id, opt.id),
      db.prepare(`UPDATE poll_options SET votes = votes + 1 WHERE id = ?`).bind(opt.id),
    ]);
  }
  const { results } = await db.prepare(`SELECT id, label, votes FROM poll_options WHERE post_id = ?`).bind(opt.post_id).all();
  return Response.json(results);
}
