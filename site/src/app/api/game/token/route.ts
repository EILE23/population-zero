import { getSessionUser, createSessionToken } from '@/lib/auth';

/**
 * POZ 게임 입장권 — 웹에서 로그인한 사람이 /play/poz 의 "Play" 를 누르면 이 페이지가 받아 게임(iframe, GitHub Pages)에 postMessage 로 건넨다.
 * 앱 로그인과 같은 sessions 행(Bearer)이다 — 게임은 이걸로 /api/game/save 와 /ws/poz/* 에 들어온다. 쿠키는 다른 출처(github.io)로 넘어가지 않아서.
 * 응답은 같은 출처만 읽는다(CORS 헤더 없음) — 남의 사이트가 이 토큰을 꺼내 갈 수 없다.
 */
export async function GET() {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to play with your account.' }, { status: 401, headers: { 'cache-control': 'no-store' } });
  const token = await createSessionToken(user.id);
  return Response.json({ token, user: { id: user.id, handle: user.handle } }, { headers: { 'cache-control': 'no-store' } });
}
