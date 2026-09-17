import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';

const MAX = 600;

/**
 * 방명록에 한 줄. 블로그 주인의 handle 로 받는다 — 페이지 행이 아직 없는 사람(=꾸민 적 없는 블로그)에게도
 * 남길 수 있어야 하고, 그게 이 기능의 요점이다. 없으면 빈 페이지 행을 만들어 거기 붙인다.
 *
 * 앱도 같은 경로를 쓴다(Bearer 토큰). 스킨과 달리 방명록은 웹 전용이 아니라 블로그의 기능이다.
 */
export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) {
    return Response.json({ error: 'unauthorized', message: 'Log in to sign a guestbook.' }, { status: 401 });
  }

  const b = (await request.json().catch(() => ({}))) as { handle?: unknown; body?: unknown };
  const handle = String(b.handle ?? '').trim();
  const body = String(b.body ?? '').replace(/\r/g, '').trim().slice(0, MAX);
  if (!/^[\w.-]{1,40}$/.test(handle)) return Response.json({ error: 'no_blog' }, { status: 404 });
  if (body.length < 2) return Response.json({ error: 'short', message: 'Write something first.' }, { status: 400 });
  if (await rateLimited(request, 'guestbook', 12, 60)) {
    return Response.json({ error: 'rate', message: 'Too many notes for now. Try later.' }, { status: 429 });
  }

  const db = await getDb();
  const owner =
    await db.prepare(`SELECT id, 'user' AS kind FROM users WHERE handle = ? COLLATE NOCASE AND guest = 0`).bind(handle).first<{ id: number; kind: string }>()
    ?? await db.prepare(`SELECT id, 'resident' AS kind FROM residents WHERE lower(replace(handle,' ','-')) = lower(?)`).bind(handle).first<{ id: number; kind: string }>();
  if (!owner) return Response.json({ error: 'no_blog', message: 'No such blog.' }, { status: 404 });

  const col = owner.kind === 'user' ? 'user_id' : 'resident_id';
  let page = await db.prepare(`SELECT id FROM pages WHERE ${col} = ?`).bind(owner.id).first<{ id: number }>();
  if (!page) {
    // 꾸민 적 없는 블로그에도 방명록은 있어야 한다 — 빈 페이지 행만 만들어 둔다(스킨은 비어 있음)
    page = await db.prepare(`INSERT INTO pages (${col}) VALUES (?) RETURNING id`).bind(owner.id).first<{ id: number }>();
  }
  if (!page) return Response.json({ error: 'failed' }, { status: 500 });

  await db.prepare(`INSERT INTO guestbook (page_id, user_id, body) VALUES (?, ?, ?)`).bind(page.id, user.id, body).run();
  return Response.json({ ok: true });
}
