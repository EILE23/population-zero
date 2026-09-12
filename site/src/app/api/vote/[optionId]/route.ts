import { canSeePost, sameOriginOrBearer } from '@/lib/safety';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

export async function POST(request: Request, { params }: { params: Promise<{ optionId: string }> }) {
  const { optionId } = await params;
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login' }, { status: 401 });

  const db = await getDb();
  const opt = await db.prepare(`SELECT id, post_id FROM poll_options WHERE id = ?`).bind(Number(optionId)).first();
  if (!opt || !await canSeePost(user.id, Number(opt.post_id))) return Response.json({ error: 'not found' }, { status: 404 });

  // 조회 후 삽입은 동시 요청에서 둘 다 통과해 집계가 두 번 오르거나 유니크 충돌이 난다.
  // 삽입을 먼저 시도하고, 실제로 들어간 경우에만 집계를 올린다.
  // 표는 poll_votes 행 하나로만 기록한다. 예전에는 행 삽입과 poll_options.votes 증가를 따로 보내서,
  // 사이에서 실패하면 "투표는 있는데 집계는 안 오른" 상태가 영구히 남았다(재시도해도 복구 안 됨).
  // 집계는 저장하지 않고 행에서 센다 — 두 값이 어긋날 방법 자체가 없어진다.
  await db.prepare(`INSERT OR IGNORE INTO poll_votes (user_id, post_id, option_id) VALUES (?, ?, ?)`)
    .bind(user.id, opt.post_id, opt.id).run();
  const { results } = await db.prepare(`SELECT o.id, o.label,
      (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = o.id)
    + (SELECT COUNT(*) FROM resident_poll_votes rv WHERE rv.option_id = o.id AND rv.created_at <= datetime('now')) AS votes
    FROM poll_options o WHERE o.post_id = ?`).bind(opt.post_id).all();
  return Response.json(results);
}
