import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { deviceHash, LINK_MINUTES, newLinkCode } from '@/lib/game-link';

/**
 * POZ 클라이언트 기기 연결 시작 — 게임이 부른다(로그인 불필요). 기기 비밀(device)과 사람이 볼 코드(code)를 준다.
 * 게임은 브라우저로 url 을 열고, interval 초마다 /api/game/link/poll 에 device 를 보내 토큰을 기다린다.
 */
export async function POST(request: Request) {
  if (await rateLimited(request, 'game-link', 10, 10)) return Response.json({ error: 'rate', message: 'Too many sign-in attempts. Try again in a few minutes.' }, { status: 429 });
  const db = await getDb();
  await db.prepare(`DELETE FROM game_links WHERE expires_at < datetime('now')`).run();
  const device = Array.from(crypto.getRandomValues(new Uint8Array(32)), (x) => x.toString(16).padStart(2, '0')).join('');
  const code = newLinkCode();
  await db.prepare(`INSERT INTO game_links (device, code, expires_at) VALUES (?1, ?2, datetime('now', ?3))`)
    .bind(await deviceHash(device), code, `+${LINK_MINUTES} minutes`).run();
  const url = new URL(`/link?code=${code}`, request.url).toString();
  return Response.json({ device, code, url, interval: 3, expires_in: LINK_MINUTES * 60 }, { headers: { 'cache-control': 'no-store' } });
}
