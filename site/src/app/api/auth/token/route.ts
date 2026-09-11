import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { verifyPassword, createSessionToken, revokeSessionToken, getSessionUser } from '@/lib/auth';
import { fireGaEvent } from '@/lib/ga-mp';

/**
 * 모바일 앱(poz) 로그인 — 웹과 같은 계정·같은 sessions 테이블을 쓴다.
 * 앱은 받은 토큰을 안전 저장소에 보관하고 이후 Authorization: Bearer 로 보낸다.
 */
export async function POST(request: Request) {
  if (await authRateLimited(request)) {
    return Response.json({ error: 'rate' }, { status: 429 });
  }
  let handle = '';
  let password = '';
  try {
    const body = (await request.json()) as { handle?: string; password?: string };
    handle = String(body.handle ?? '').trim();
    password = String(body.password ?? '');
  } catch {
    return Response.json({ error: 'bad_request' }, { status: 400 });
  }
  if (!handle || !password) return Response.json({ error: 'bad_request' }, { status: 400 });

  const db = await getDb();
  const user = await db.prepare(
    `SELECT id, handle, email, avatar_url, email_verified FROM users WHERE handle = ? COLLATE NOCASE`,
  ).bind(handle).first<{ id: number; handle: string; email: string | null; avatar_url: string | null; email_verified: number }>();
  const hashRow = user
    ? await db.prepare(`SELECT password_hash FROM users WHERE id = ?`).bind(user.id).first<{ password_hash: string | null }>()
    : null;

  // 존재하지 않는 계정과 틀린 비밀번호를 같은 응답으로 — 계정 존재 여부가 새지 않게
  if (!user || !hashRow?.password_hash || !(await verifyPassword(password, hashRow.password_hash))) {
    return Response.json({ error: 'bad_credentials' }, { status: 401 });
  }

  const token = await createSessionToken(user.id);
  await fireGaEvent('login', request, { method: 'app' }, user.id);
  return Response.json({
    token,
    user: {
      id: user.id,
      handle: user.handle,
      email: user.email,
      avatar_url: user.avatar_url,
      email_verified: !!user.email_verified,
    },
  });
}

/** 앱 로그아웃 — 이 토큰의 세션만 폐기한다 */
export async function DELETE(request: Request) {
  const bearer = request.headers.get('authorization');
  if (bearer?.startsWith('Bearer ')) await revokeSessionToken(bearer.slice(7).trim());
  return new Response(null, { status: 204 });
}

/** 앱 기동 시 토큰이 아직 유효한지 확인 — 유효하면 현재 사용자를 돌려준다 */
export async function GET() {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'unauthorized' }, { status: 401 });
  return Response.json({
    user: {
      id: user.id,
      handle: user.handle,
      email: user.email,
      avatar_url: user.avatar_url,
      email_verified: !!user.email_verified,
    },
  });
}
