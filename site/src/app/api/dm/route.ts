import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { uploadImageToAssets } from '@/lib/assets';
import { cleanBody, threadKey, type Party } from '@/lib/dm';
import { rateLimited } from '@/lib/ratelimit';

type ThreadRow = {
  thread: string;
  body: string;
  created_at: string;
  last_id: number;
  unread: number;
  other_handle: string;
  other_kind: string;
  other_id: number;
  other_avatar: string | null;
};

/**
 * 내 쪽지함 — 대화마다 마지막 한 줄과 안 읽은 개수.
 * 웹은 이걸 목록으로, 앱은 채팅 목록으로 그린다. 같은 데이터다.
 */
export async function GET() {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });

  const db = await getDb();
  const { results } = await db.prepare(`
    WITH mine AS (
      SELECT * FROM dms WHERE from_user_id = ?1 OR to_user_id = ?1
    ),
    last AS (
      SELECT thread, MAX(id) AS last_id FROM mine GROUP BY thread
    )
    SELECT m.thread, m.body, m.created_at, l.last_id,
      (SELECT COUNT(*) FROM mine x WHERE x.thread = m.thread AND x.to_user_id = ?1 AND x.read_at IS NULL) AS unread,
      COALESCE(ru.handle, rr.handle, 'someone') AS other_handle,
      CASE WHEN ru.id IS NOT NULL THEN 'user' ELSE 'resident' END AS other_kind,
      COALESCE(ru.id, rr.id, 0) AS other_id,
      ru.avatar_url AS other_avatar
    FROM last l
    JOIN mine m ON m.id = l.last_id
    -- 상대는 "내가 아닌 쪽" — 보낸 사람이 나면 받는 사람이, 아니면 보낸 사람이 상대다
    LEFT JOIN users ru ON ru.id = CASE WHEN m.from_user_id = ?1 THEN m.to_user_id ELSE m.from_user_id END
    LEFT JOIN residents rr ON rr.id = CASE WHEN m.from_user_id = ?1 THEN m.to_resident_id ELSE m.from_resident_id END
    ORDER BY l.last_id DESC LIMIT 50`).bind(user.id).all<ThreadRow>();

  return Response.json({
    threads: results.map((t) => ({
      thread: t.thread,
      preview: t.body.slice(0, 140),
      created_at: t.created_at,
      unread: t.unread,
      other: { kind: t.other_kind, id: t.other_id, handle: t.other_handle, avatar: t.other_avatar },
    })),
  }, { headers: { 'cache-control': 'no-store' } });
}

/**
 * 쪽지 보내기 — 상대는 사람(handle) 또는 주민(handle). 핸들 하나로 둘 다 찾는다.
 * 사진을 붙일 때만 multipart 로 오고, 글만 보낼 때는 JSON 으로 온다.
 */
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  if (!user.email_verified) return Response.json({ error: 'unverified' }, { status: 403 });
  if (await rateLimited(request, 'dm', 30, 5, true)) return Response.json({ error: 'rate' }, { status: 429 });

  const multipart = (request.headers.get('content-type') ?? '').includes('multipart/form-data');
  let body = '';
  let handle = '';
  let image: string | null = null;
  if (multipart) {
    const form = await request.formData();
    body = cleanBody(form.get('body'));
    handle = String(form.get('to') ?? '').trim();
    const file = form.get('image');
    if (file instanceof File && file.size > 0) image = await uploadImageToAssets(file, user.id, 'inline');
  } else {
    const input = (await request.json().catch(() => ({}))) as { to?: string; body?: string };
    body = cleanBody(input.body);
    handle = String(input.to ?? '').trim();
  }
  // 사진만 보내는 것도 말이다 — 둘 다 없을 때만 거절한다
  if (!body && !image) return Response.json({ error: 'empty' }, { status: 400 });
  if (!handle) return Response.json({ error: 'no_recipient' }, { status: 400 });

  const db = await getDb();
  const [asUser, asResident] = await db.batch([
    db.prepare(`SELECT id FROM users WHERE handle = ?`).bind(handle),
    db.prepare(`SELECT id FROM residents WHERE handle = ?`).bind(handle),
  ]);
  const toUser = (asUser.results as { id: number }[])[0]?.id ?? null;
  const toResident = toUser ? null : (asResident.results as { id: number }[])[0]?.id ?? null;
  if (toUser === null && toResident === null) return Response.json({ error: 'not_found' }, { status: 404 });
  if (toUser === user.id) return Response.json({ error: 'self' }, { status: 400 });

  const me: Party = { kind: 'user', id: user.id };
  const them: Party = toUser ? { kind: 'user', id: toUser } : { kind: 'resident', id: toResident! };
  const thread = threadKey(me, them);

  const { meta } = await db.prepare(
    `INSERT INTO dms (thread, from_user_id, to_user_id, to_resident_id, body, image) VALUES (?, ?, ?, ?, ?, ?)`,
  ).bind(thread, user.id, toUser, toResident, body, image).run();

  return Response.json({ ok: true, id: Number(meta.last_row_id), thread, image }, { status: 201 });
}
