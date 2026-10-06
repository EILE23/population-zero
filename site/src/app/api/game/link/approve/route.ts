import { createSessionToken, getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { normalizeCode } from '@/lib/game-link';

/**
 * POZ 클라이언트 기기 연결 승인 — /link 의 Connect 버튼(로그인한 웹 세션, 같은 출처 폼). 그 코드의 행에 새 세션 토큰을 싣는다.
 * 다른 사이트가 이 폼을 대신 보내지 못하게 Origin 을 본다(SameSite=Lax 쿠키도 교차 POST 엔 안 실린다).
 */
export async function POST(request: Request) {
  const origin = request.headers.get('origin');
  if (origin && origin !== new URL(request.url).origin) return new Response('Forbidden', { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.redirect(new URL('/login', request.url), 303);
  const form = await request.formData();
  const code = normalizeCode(String(form.get('code') ?? ''));
  const back = (q: string) => Response.redirect(new URL(`/link?${q}`, request.url), 303);
  if (!code) return back('error=code');
  const db = await getDb();
  const row = await db.prepare(`SELECT device FROM game_links WHERE code = ? AND token IS NULL AND expires_at >= datetime('now')`).bind(code).first<{ device: string }>();
  if (!row) return back(`error=expired`);
  const token = await createSessionToken(user.id);
  await db.prepare(`UPDATE game_links SET user_id = ?1, token = ?2 WHERE device = ?3`).bind(user.id, token, row.device).run();
  return back('done=1');
}
