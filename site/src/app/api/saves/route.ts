import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { sameOriginOrBearer } from '@/lib/safety';

/**
 * 나중에 읽기 — 글(post)과 뉴스 항목(trend) 둘 다 같은 표에 담는다.
 * 켜고 끄는 한 번의 요청으로 끝난다(on: true/false). 게스트도 저장할 수 있다 — 브라우저 세션에 매여 있다가
 * 가입하면 그 계정으로 따라온다(users 행이 그대로 승격되므로).
 */
/** 내가 저장한 것들의 id — 뉴스 피드가 한 번 읽어 카드마다 상태를 표시한다 */
export async function GET(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ ids: [] });
  const kind = new URL(request.url).searchParams.get('kind') === 'post' ? 'post' : 'trend';
  const { results } = await (await getDb())
    .prepare(`SELECT ref_id FROM saves WHERE user_id = ? AND kind = ? ORDER BY created_at DESC LIMIT 500`)
    .bind(user.id, kind).all<{ ref_id: number }>();
  return Response.json({ ids: results.map((r) => r.ref_id) }, { headers: { 'cache-control': 'no-store' } });
}

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized', message: 'Sign in to save things.' }, { status: 401 });

  const { kind, ref_id: refId, on } = (await request.json().catch(() => ({}))) as { kind?: string; ref_id?: unknown; on?: unknown };
  if (kind !== 'post' && kind !== 'trend') return Response.json({ error: 'bad_request' }, { status: 400 });
  const id = Number(refId);
  if (!Number.isInteger(id) || id <= 0) return Response.json({ error: 'bad_request' }, { status: 400 });

  const db = await getDb();
  if (on === false) {
    await db.prepare(`DELETE FROM saves WHERE user_id = ? AND kind = ? AND ref_id = ?`).bind(user.id, kind, id).run();
    return Response.json({ saved: false });
  }
  // 없는 것을 저장했다고 말하지 않는다 — 삭제된 글·지나간 뉴스 항목은 거절한다
  const exists = kind === 'post'
    ? await db.prepare(`SELECT 1 FROM posts WHERE id = ? AND hidden = 0`).bind(id).first()
    : await db.prepare(`SELECT 1 FROM trends WHERE id = ?`).bind(id).first();
  if (!exists) return Response.json({ error: 'not_found' }, { status: 404 });

  await db.prepare(`INSERT OR IGNORE INTO saves (user_id, kind, ref_id) VALUES (?, ?, ?)`).bind(user.id, kind, id).run();
  return Response.json({ saved: true });
}
