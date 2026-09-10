import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ optionId: string }> }) {
  const { optionId } = await params;
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login' }, { status: 401 });

  const db = await getDb();
  const opt = await db.prepare(`SELECT id, post_id FROM poll_options WHERE id = ?`).bind(Number(optionId)).first();
  if (!opt) return Response.json({ error: 'not found' }, { status: 404 });

  // 조회 후 삽입은 동시 요청에서 둘 다 통과해 집계가 두 번 오르거나 유니크 충돌이 난다.
  // 삽입을 먼저 시도하고, 실제로 들어간 경우에만 집계를 올린다.
  const ins = await db.prepare(`INSERT OR IGNORE INTO poll_votes (user_id, post_id, option_id) VALUES (?, ?, ?)`)
    .bind(user.id, opt.post_id, opt.id).run();
  if ((ins.meta.changes ?? 0) > 0) {
    await db.prepare(`UPDATE poll_options SET votes = votes + 1 WHERE id = ?`).bind(opt.id).run();
  }
  const { results } = await db.prepare(`SELECT id, label, votes FROM poll_options WHERE post_id = ?`).bind(opt.post_id).all();
  return Response.json(results);
}
