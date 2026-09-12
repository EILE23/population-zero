import { visibleTo, sameOriginOrBearer } from '@/lib/safety';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const COVERED = new Set(['US', 'GB', 'KR', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG']);

/** 접속한 나라가 곧 방 이름 — 우리가 다루지 않는 나라는 한 방(world)에 모인다 */
function roomOf(request: Request, asked: string | null): string {
  const c = (asked || request.headers.get('cf-ipcountry') || '').toUpperCase();
  return COVERED.has(c) ? c : 'WORLD';
}

type Row = {
  id: number;
  body: string;
  created_at: string;
  handle: string;
  avatar: string | null;
  is_resident: number;
  user_id: number | null;
};

/**
 * 나라 방 — 같은 나라에 있는 사람들이 지금 같이 말하는 곳.
 * 글·댓글은 남기는 말이고 여기는 지나가는 말이다. 그래서 제목도 좋아요도 없다.
 * 주민(AI)도 순찰 때 이 방에 들어온다.
 *
 * 실시간은 짧은 폴링으로 한다 — 화면이 열려 있는 동안만, 마지막으로 받은 id 뒤의 것만 가져오므로
 * 새 말이 없으면 빈 배열 하나로 끝난다(무료 티어에서 웹소켓·Durable Objects 를 쓰지 않는 이유).
 */
export async function GET(request: Request) {
  const viewer = await getSessionUser();
  const url = new URL(request.url);
  const room = roomOf(request, url.searchParams.get('room'));
  const after = Math.max(0, Number(url.searchParams.get('after')) || 0);

  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT m.id, m.body, m.created_at, m.user_id,
      COALESCE(r.handle, u.handle, 'someone') AS handle,
      u.avatar_url AS avatar,
      (m.resident_id IS NOT NULL) AS is_resident
    FROM room_messages m
    LEFT JOIN residents r ON r.id = m.resident_id
    LEFT JOIN users u ON u.id = m.user_id
    WHERE m.room = ? AND m.hidden = 0 AND m.id > ? AND m.created_at <= datetime('now') AND ${visibleTo(viewer?.id ?? 0, 'm.user_id', 'm.resident_id')}
    ORDER BY m.id DESC LIMIT 60`).bind(room, after).all<Row>();

  // 최신순으로 읽고 화면 순서(오래된 것 → 새것)로 뒤집는다
  const messages = results.reverse().map((m) => ({
    id: m.id,
    body: m.body,
    created_at: m.created_at,
    handle: m.handle,
    avatar: m.avatar,
    is_resident: !!m.is_resident,
    user_id: m.user_id,
  }));

  return Response.json({ room, messages }, { headers: { 'cache-control': 'no-store' } });
}

/** 한마디 하기 — 로그인·이메일 인증이 끝난 사람만 (글·댓글과 같은 문턱) */
export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  if (!user.email_verified) return Response.json({ error: 'unverified' }, { status: 403 });
  if (await rateLimited(request, 'room', 20, 1)) return Response.json({ error: 'rate' }, { status: 429 });

  const input = (await request.json().catch(() => ({}))) as { body?: string; room?: string };
  const body = String(input.body ?? '').replace(CONTROL_CHARS, '').trim().slice(0, 500);
  if (body.length < 1) return Response.json({ error: 'empty' }, { status: 400 });

  const room = roomOf(request, input.room ?? null);
  const db = await getDb();
  const { meta } = await db.prepare(
    `INSERT INTO room_messages (room, user_id, body) VALUES (?, ?, ?)`,
  ).bind(room, user.id, body).run();

  return Response.json({ ok: true, id: Number(meta.last_row_id), room }, { status: 201 });
}
