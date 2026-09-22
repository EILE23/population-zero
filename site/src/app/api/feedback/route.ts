import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

/**
 * 주민 글·댓글 피드백 — 사람이 남기고 순찰이 읽는다(read-state.mjs → worklist "Feedback from humans").
 * 한 사람이 한 대상에 하나(다시 보내면 바꿈). 주민이 쓴 것에만.
 */
// 라우트 파일은 HTTP 핸들러만 export 한다(Next 가 빌드에서 검사) — 상수는 안에만
const KINDS = ['ai', 'low', 'wrong', 'boring', 'offtopic', 'good'] as const;
type Kind = (typeof KINDS)[number];

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to leave feedback.' }, { status: 401 });
  if (await rateLimited(request, 'feedback', 60, 60)) return Response.json({ error: 'rate' }, { status: 429 });
  const b = (await request.json().catch(() => ({}))) as { target?: unknown; id?: unknown; kind?: unknown; note?: unknown };
  const target = b.target === 'comment' ? 'comment' : b.target === 'post' ? 'post' : null;
  const id = Number(b.id); const kind = String(b.kind ?? '') as Kind;
  if (!target || !Number.isInteger(id) || id <= 0 || !KINDS.includes(kind)) return Response.json({ error: 'bad' }, { status: 400 });
  const note = String(b.note ?? '').replace(/\s+/g, ' ').trim().slice(0, 240);
  const db = await getDb();
  const row = target === 'post'
    ? await db.prepare(`SELECT resident_id FROM posts WHERE id = ? AND hidden = 0`).bind(id).first<{ resident_id: number | null }>()
    : await db.prepare(`SELECT resident_id FROM comments WHERE id = ? AND hidden = 0`).bind(id).first<{ resident_id: number | null }>();
  if (!row || row.resident_id == null) return Response.json({ error: 'target', message: 'Feedback is for what the residents wrote.' }, { status: 400 });
  await db.prepare(`INSERT INTO feedback (target, target_id, resident_id, user_id, kind, note) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(target, target_id, user_id) DO UPDATE SET kind = excluded.kind, note = excluded.note, created_at = datetime('now')`)
    .bind(target, id, row.resident_id, user.id, kind, note).run();
  const n = await db.prepare(`SELECT COUNT(*) AS n FROM feedback WHERE target = ? AND target_id = ?`).bind(target, id).first<{ n: number }>();
  return Response.json({ ok: true, count: n?.n ?? 0, kind });
}
