import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { otherParty, threadParties } from '@/lib/dm';

type Row = {
  id: number;
  body: string;
  image: string | null;
  created_at: string;
  read_at: string | null;
  from_user_id: number | null;
  from_resident_id: number | null;
};

/**
 * 대화 한 줄기.
 *
 * `after` 를 주면 그 뒤에 온 것만 돌려준다 — 앱이 화면을 열어 둔 동안 2~3초마다 물어보는 용도.
 * 새 말이 없으면 빈 배열 하나로 끝나므로 무료 티어에서도 감당된다.
 * (웹소켓은 Durable Objects 가 필요해 유료다. 사람 사이 대화는 짧은 폴링으로 충분히 살아 있게 느껴진다.)
 */
export async function GET(request: Request, { params }: { params: Promise<{ thread: string }> }) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });

  const { thread } = await params;
  const me = { kind: 'user' as const, id: user.id };
  // 내가 낀 대화가 아니면 아예 없는 것으로 — 열쇠를 찍어 맞혀도 남의 대화는 열리지 않는다
  const mine = threadParties(thread).some((p) => p.kind === 'user' && p.id === user.id);
  if (!mine) return Response.json({ error: 'not_found' }, { status: 404 });

  const url = new URL(request.url);
  const after = Math.max(0, Number(url.searchParams.get('after')) || 0);

  const db = await getDb();
  const { results } = await db.prepare(
    `SELECT id, body, image, created_at, read_at, from_user_id, from_resident_id
     FROM dms WHERE thread = ? AND id > ? ORDER BY id LIMIT 200`,
  ).bind(thread, after).all<Row>();

  // 연 순간 읽음 처리 — 상대 화면의 '안 읽음'이 사라진다
  if (results.some((m) => m.from_user_id !== user.id && !m.read_at)) {
    await db.prepare(
      `UPDATE dms SET read_at = datetime('now') WHERE thread = ? AND to_user_id = ? AND read_at IS NULL AND id > ? AND id <= ?`,
    ).bind(thread, user.id, after, results[results.length - 1].id).run();
  }

  const other = otherParty(thread, me);
  const who = other?.kind === 'resident'
    ? await db.prepare(`SELECT handle FROM residents WHERE id = ?`).bind(other.id).first<{ handle: string }>()
    : other
      ? await db.prepare(`SELECT handle, avatar_url FROM users WHERE id = ?`).bind(other.id).first<{ handle: string; avatar_url: string | null }>()
      : null;

  return Response.json({
    thread,
    other: other && who
      ? { kind: other.kind, id: other.id, handle: who.handle, avatar: 'avatar_url' in who ? who.avatar_url : null }
      : null,
    // 상대가 주민이면 답장이 순찰 때 온다 — 화면이 이걸 솔직하게 말해야 고장 난 것처럼 보이지 않는다
    live: other?.kind === 'user',
    messages: results.map((m) => ({
      id: m.id,
      body: m.body,
      image: m.image,
      created_at: m.created_at,
      mine: m.from_user_id === user.id,
      read: m.read_at != null,
    })),
  }, { headers: { 'cache-control': 'no-store' } });
}
