import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

/**
 * POZ 게임 저장 — 계정마다 JSON 한 덩이(동전·기록·Climb 쉼터·손도끼 …). 게임(github.io)이 Bearer 토큰으로 읽고 쓴다.
 * 표가 따로 있는 이유: 게임 상태는 웹 기능 어디에도 맞는 칸이 없는 자유 형식이고(키를 늘리면 매번 마이그레이션), 32KB 로 묶는다.
 * 지금은 게임이 보낸 값을 믿는다(혼자 하는 게임의 저장) — 화폐를 사람끼리 주고받게 되면 서버가 계산하는 쪽으로 옮긴다.
 */
const GAME_ORIGINS = new Set(['https://eile23.github.io', 'https://population.town']);
const MAX = 32 * 1024;

function cors(request: Request): Record<string, string> {
  const o = request.headers.get('origin') ?? '';
  return GAME_ORIGINS.has(o)
    ? { 'access-control-allow-origin': o, 'access-control-allow-headers': 'authorization, content-type', 'access-control-allow-methods': 'GET, PUT, OPTIONS', 'access-control-max-age': '600', vary: 'origin', 'cache-control': 'no-store' }
    : { 'cache-control': 'no-store' };
}

export async function OPTIONS(request: Request) {
  return new Response(null, { status: 204, headers: cors(request) });
}

export async function GET(request: Request) {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to load your town.' }, { status: 401, headers: cors(request) });
  const row = await (await getDb()).prepare(`SELECT data, updated_at FROM game_saves WHERE user_id = ?`).bind(user.id).first<{ data: string; updated_at: string }>();
  let data: unknown = null;
  try { data = row ? JSON.parse(row.data) : null; } catch { data = null; }
  return Response.json({ user: { id: user.id, handle: user.handle }, data, updated_at: row?.updated_at ?? null }, { headers: cors(request) });
}

export async function PUT(request: Request) {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to save your town.' }, { status: 401, headers: cors(request) });
  if (await rateLimited(request, 'game-save', 30, 1)) return Response.json({ error: 'rate', message: 'Saving too often.' }, { status: 429, headers: cors(request) });
  const raw = await request.text();
  if (raw.length > MAX) return Response.json({ error: 'too_big', message: 'Save is too large.' }, { status: 413, headers: cors(request) });
  let body: { data?: unknown };
  try { body = JSON.parse(raw); } catch { return Response.json({ error: 'bad_request', message: 'Not JSON.' }, { status: 400, headers: cors(request) }); }
  if (!body.data || typeof body.data !== 'object' || Array.isArray(body.data)) return Response.json({ error: 'bad_request', message: 'Expected { data: {...} }.' }, { status: 400, headers: cors(request) });
  await (await getDb()).prepare(
    `INSERT INTO game_saves (user_id, data, updated_at) VALUES (?1, ?2, datetime('now'))
     ON CONFLICT(user_id) DO UPDATE SET data = ?2, updated_at = datetime('now')`,
  ).bind(user.id, JSON.stringify(body.data)).run();
  return Response.json({ ok: true }, { headers: cors(request) });
}
