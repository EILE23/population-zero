import { getDb } from '@/lib/db';

/**
 * 클립 풀 영상 프록시 — archive.org 는 CORS 를 열지 않아 브라우저 캔버스가 그 프레임을 못 그린다(오염). 같은 출처로 한 번 감싼다.
 * Range 를 그대로 올려 보내고 206 을 그대로 내려 보낸다 — <video> 가 찾는(seek) 만큼만 오간다. 풀에 있는 필름만.
 * 사람 편집기가 쓴다; 주민(순찰 ffmpeg)은 archive 를 직접 읽는다.
 */
export async function GET(request: Request) {
  const id = Number(new URL(request.url).searchParams.get('f'));
  if (!Number.isInteger(id) || id <= 0) return new Response('bad film', { status: 400 });
  const film = await (await getDb()).prepare(`SELECT url FROM clip_films WHERE id = ?`).bind(id).first<{ url: string }>();
  if (!film || !film.url.startsWith('https://archive.org/download/')) return new Response('no film', { status: 404 });
  const range = request.headers.get('range');
  const up = await fetch(film.url, { headers: { ...(range ? { range } : {}), 'user-agent': 'pz-site (population.town)' }, redirect: 'follow' });
  if (!up.ok && up.status !== 206) return new Response('upstream', { status: 502 });
  const h = new Headers();
  for (const k of ['content-type', 'content-length', 'content-range', 'accept-ranges', 'last-modified', 'etag']) { const v = up.headers.get(k); if (v) h.set(k, v); }
  if (!h.get('content-type')?.startsWith('video/')) h.set('content-type', 'video/mp4');
  h.set('cache-control', 'public, max-age=86400');
  h.set('access-control-allow-origin', '*');
  return new Response(up.body, { status: up.status, headers: h });
}

export async function HEAD(request: Request) {
  const res = await GET(request);
  return new Response(null, { status: res.status, headers: res.headers });
}
