import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { hashPassword, createSessionToken, validHandle, validPassword } from '@/lib/auth';
import { sendMail, verifyEmailHtml } from '@/lib/mail';
import { fireGaEvent } from '@/lib/ga-mp';

/**
 * 모바일 앱(poz) 회원가입 — 웹 /api/auth/signup 과 같은 규칙·같은 테이블을 쓰고,
 * 리다이렉트 대신 JSON 과 세션 토큰을 돌려준다. 가입 즉시 로그인 상태가 된다.
 */
export async function POST(request: Request) {
  if (await authRateLimited(request)) return Response.json({ error: 'rate' }, { status: 429 });

  let handle = '';
  let email = '';
  let password = '';
  try {
    const b = (await request.json()) as { handle?: string; email?: string; password?: string };
    handle = String(b.handle ?? '').trim();
    email = String(b.email ?? '').trim().toLowerCase();
    password = String(b.password ?? '');
  } catch {
    return Response.json({ error: 'bad_request' }, { status: 400 });
  }

  if (!validHandle(handle)) return Response.json({ error: 'handle' }, { status: 400 });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) || email.length > 254) return Response.json({ error: 'email' }, { status: 400 });
  if (!validPassword(password)) return Response.json({ error: 'password' }, { status: 400 });

  const db = await getDb();
  // 회원·AI 주민 핸들 모두와 충돌 검사 — 사람이 주민 핸들을 선점하면 그 주민 블로그가 가려진다
  const exists = await db.prepare(`
    SELECT 1 AS y FROM users WHERE handle = ?1 COLLATE NOCASE
    UNION SELECT 1 FROM residents WHERE handle = ?1 COLLATE NOCASE OR lower(replace(handle,' ','-')) = lower(?1)
    LIMIT 1`).bind(handle).first();
  if (exists) return Response.json({ error: 'taken' }, { status: 409 });

  const emailTaken = await db.prepare(`SELECT 1 AS y FROM users WHERE email = ?`).bind(email).first();
  if (emailTaken) return Response.json({ error: 'emailtaken' }, { status: 409 });

  const hash = await hashPassword(password);
  const { meta } = await db.prepare(
    `INSERT INTO users (handle, email, password_hash, handle_picked) VALUES (?, ?, ?, 1)`,
  ).bind(handle, email, hash).run();
  const userId = Number(meta.last_row_id);

  // 인증 메일 — 실패해도 가입은 진행된다(열람 가능, 글·댓글만 인증 후)
  const token = crypto.randomUUID().replace(/-/g, '');
  await db.prepare(
    `INSERT INTO auth_tokens (token, user_id, kind, expires_at) VALUES (?, ?, 'verify', datetime('now', '+2 days'))`,
  ).bind(token, userId).run();
  await sendMail(email, 'Verify your email — POZ', verifyEmailHtml(token));

  await fireGaEvent('sign_up', request, { method: 'app' }, userId);

  const sessionToken = await createSessionToken(userId);
  return Response.json({
    token: sessionToken,
    user: { id: userId, handle, email, avatar_url: null, email_verified: false },
  }, { status: 201 });
}
