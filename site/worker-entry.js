// 엣지 캐시 래퍼 — HN/레딧 급유입에서 무료 티어(CPU·D1)를 보호한다.
// 로그아웃 방문자의 전체 페이지 GET 만 60초 캐시. 로그인 사용자, /api, RSC/프리페치
// (클라이언트 내비게이션은 같은 URL 로 flight 데이터를 요청하므로 섞이면 화면이 깨진다)는 전부 통과.
import handler from './.open-next/worker.js';

export { DOQueueHandler } from './.open-next/.build/durable-objects/queue.js';
export { DOShardedTagCache } from './.open-next/.build/durable-objects/sharded-tag-cache.js';
export { BucketCachePurge } from './.open-next/.build/durable-objects/bucket-cache-purge.js';
export { ChatRoom } from './chat-room.js';

const SKIP_PREFIX = ['/api/', '/admin', '/me', '/reset', '/write'];

// 피드는 방문자 국가(cf-ipcountry)와 글의 region 이 **정확히** 일치할 때만 가중치를 준다.
// 그래서 캐시 키도 정확한 국가여야 한다. 전에는 US/GB/CA 를 한 묶음으로 캐싱했는데,
// 그러면 먼저 온 US 방문자의 정렬이 60초 동안 GB 방문자에게도 나갔다.
// 트래픽 규모상 국가별로 쪼개져도 캐시 효율 손해는 작다.
const cacheCountry = (request) => ((request.headers.get('cf-ipcountry') || 'XX').toUpperCase().match(/^[A-Z]{2}$/) || ['XX'])[0];

function cacheable(request, url) {
  if (request.method !== 'GET') return false;
  if ((request.headers.get('cookie') || '').includes('pz_session=')) return false;
  if (request.headers.has('authorization')) return false;
  if (request.headers.get('rsc') || request.headers.get('next-router-prefetch') || request.headers.get('next-router-state-tree')) return false;
  return !SKIP_PREFIX.some((p) => url.pathname === p.replace(/\/$/, '') || url.pathname.startsWith(p));
}

/**
 * 앱 채팅의 실시간 연결.
 * 웹소켓은 헤더를 붙일 수 없어(모바일 클라이언트 제약) 토큰을 쿼리로 받는다 — 여기서 한 번 검증하고,
 * 그 대화의 참가자인지 확인한 뒤에야 방(DO)으로 넘긴다. 방은 누가 왔는지 다시 묻지 않는다.
 */
async function openChatSocket(request, env) {
  const url = new URL(request.url);
  const thread = url.searchParams.get('thread') ?? '';
  const token = url.searchParams.get('token') ?? '';
  if (!thread || !token) return new Response('bad request', { status: 400 });

  const row = await env.DB.prepare(
    `SELECT s.user_id, u.email_verified FROM sessions s JOIN users u ON u.id = s.user_id
     WHERE s.token = ? AND julianday(s.expires_at) > julianday('now')`,
  ).bind(token).first();
  if (!row) return new Response('unauthorized', { status: 401 });
  if (!row.email_verified) return new Response('unverified', { status: 403 });

  // 열쇠를 찍어 맞혀도 남의 대화는 열리지 않는다
  const tags = thread.split('|');
  if (tags.length !== 2 || tags[0] === tags[1] || tags.join('|') !== [...tags].sort().join('|') ||
      !tags.every(t => /^(u[1-9]\d*|r(?:0|[1-9]\d*))$/.test(t) && Number.isSafeInteger(Number(t.slice(1)))) ||
      !tags.includes(`u${row.user_id}`)) return new Response('not found', { status: 404 });
  const other = tags.find(t => t !== `u${row.user_id}`);
  const recipient = await env.DB.prepare(other.startsWith('u')
    ? 'SELECT id FROM users WHERE id = ?' : 'SELECT id FROM residents WHERE id = ?')
    .bind(Number(other.slice(1))).first();
  if (!recipient) return new Response('not found', { status: 404 });

  const stub = env.CHAT_ROOM.get(env.CHAT_ROOM.idFromName(thread));
  const forward = new URL(request.url);
  forward.searchParams.set('uid', String(row.user_id));
  // The room rechecks this session on every send, including after logout/expiry.
  return stub.fetch(new Request(forward.toString(), request));
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === '/ws/dm') return openChatSocket(request, env);
    if (url.pathname === '/api/dm' && request.method === 'POST') {
      const res = await handler.fetch(request, env, ctx);
      if (res.status === 201) {
        ctx.waitUntil((async () => {
          const { thread, id } = await res.clone().json();
          const stub = env.CHAT_ROOM.get(env.CHAT_ROOM.idFromName(thread));
          await stub.fetch(new Request(`https://room.internal/notify?thread=${encodeURIComponent(thread)}&id=${id}`, { method: 'POST' }));
        })().catch(error => console.error('DM notification failed', error)));
      }
      return res;
    }
    if (!cacheable(request, url)) return handler.fetch(request, env, ctx);

    const cache = caches.default;
    const keyUrl = new URL(url.toString());
    keyUrl.searchParams.set('_c', cacheCountry(request)); // 캐시 키 전용 — 원본 요청은 그대로 넘어간다
    const key = new Request(keyUrl.toString(), { method: 'GET' });
    const hit = await cache.match(key);
    if (hit) {
      const res = new Response(hit.body, hit);
      res.headers.set('x-pz-edge', 'HIT');
      return res;
    }

    const res = await handler.fetch(request, env, ctx);
    const ct = res.headers.get('content-type') || '';
    const isText = ct.includes('text/html') || ct.includes('xml') || ct.includes('text/plain') || ct.includes('application/rss');
    if (res.status === 200 && isText && !res.headers.get('set-cookie')) {
      const copy = new Response(res.clone().body, res);
      copy.headers.set('cache-control', 'public, max-age=60');
      ctx.waitUntil(cache.put(key, copy));
    }
    const out = new Response(res.body, res);
    out.headers.set('x-pz-edge', 'MISS');
    return out;
  },
};
