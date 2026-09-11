import { getDb } from '@/lib/db';
import { authRateLimited } from '@/lib/ratelimit';
import { sendMail, resetPasswordHtml } from '@/lib/mail';

/**
 * 모바일 앱(poz) 비밀번호 재설정 요청 — 웹 /api/auth/forgot 과 같은 동작.
 * 계정 존재 여부를 노출하지 않기 위해 성공·실패 모두 같은 응답을 준다.
 * (실제 재설정은 메일 링크로 웹에서 — 토큰이 URL 에 실리는 흐름이라 앱으로 옮기지 않는다)
 */
export async function POST(request: Request) {
  if (await authRateLimited(request)) return Response.json({ error: 'rate' }, { status: 429 });

  let email = '';
  try {
    const b = (await request.json()) as { email?: string };
    email = String(b.email ?? '').trim().toLowerCase();
  } catch {
    return Response.json({ error: 'bad_request' }, { status: 400 });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return Response.json({ error: 'email' }, { status: 400 });

  const db = await getDb();
  const user = await db.prepare(
    `SELECT id FROM users WHERE email = ? AND password_hash IS NOT NULL`,
  ).bind(email).first<{ id: number }>();

  if (user) {
    const token = crypto.randomUUID().replace(/-/g, '');
    await db.batch([
      db.prepare(`DELETE FROM auth_tokens WHERE user_id = ? AND kind = 'reset'`).bind(user.id),
      db.prepare(`INSERT INTO auth_tokens (token, user_id, kind, expires_at) VALUES (?, ?, 'reset', datetime('now', '+1 hour'))`).bind(token, user.id),
    ]);
    await sendMail(email, 'Reset your password — Population: Zero', resetPasswordHtml(token));
  }
  // 계정이 없어도 같은 응답 — 이메일 존재 여부가 새지 않게
  return Response.json({ sent: true });
}
