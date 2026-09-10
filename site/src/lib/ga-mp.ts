import { getEnv } from '@/lib/db';

const MEASUREMENT_ID = 'G-G3GZC8PBVD';
const SESSION_COOKIE = '_ga_G3GZC8PBVD';

function cookieValue(request: Request, name: string): string | null {
  const raw = request.headers.get('cookie') || '';
  for (const part of raw.split(';')) {
    const [key, ...rest] = part.trim().split('=');
    if (key === name) return decodeURIComponent(rest.join('='));
  }
  return null;
}

function gaClientId(request: Request): string | null {
  const raw = cookieValue(request, '_ga');
  if (!raw) return null;
  const parts = raw.split('.');
  if (parts.length < 4) return null;
  return `${parts.at(-2)}.${parts.at(-1)}`;
}

function gaSessionId(request: Request): string | null {
  const raw = cookieValue(request, SESSION_COOKIE);
  if (!raw) return null;

  // Current GA4 cookies may use GS2.1.s<session>... while older ones used GS1.1.<session>...
  const gs2 = raw.match(/(?:^|[.$])s(\d+)(?:[.$]|$)/);
  if (gs2?.[1]) return gs2[1];
  const gs1 = raw.match(/^GS\d+\.\d+\.(\d+)/);
  return gs1?.[1] ?? null;
}

// GA4 Measurement Protocol — 핵심 서버 이벤트.
// 브라우저의 실제 GA client/session id를 재사용해 acquisition → conversion attribution을 유지한다.
// GA cookie 또는 secret이 없으면 조용히 생략한다. 합성 client id는 사용자 여정을 분리하므로 만들지 않는다.
export async function fireGaEvent(
  name: string,
  request: Request,
  params: Record<string, string | number | boolean> = {},
  userId?: number,
): Promise<void> {
  try {
    // 관리자 계정은 클라이언트 GA와 서버 Measurement Protocol 모두 제외한다.
    if (cookieValue(request, 'pz_noga') === '1') return;

    const { GA_MP_SECRET } = await getEnv();
    if (!GA_MP_SECRET) return;

    const clientId = gaClientId(request);
    if (!clientId) return;
    const sessionId = gaSessionId(request);

    await fetch(`https://www.google-analytics.com/mp/collect?measurement_id=${MEASUREMENT_ID}&api_secret=${GA_MP_SECRET}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        ...(userId ? { user_id: String(userId) } : {}),
        events: [{
          name,
          params: {
            engagement_time_msec: 100,
            ...(sessionId ? { session_id: sessionId } : {}),
            ...params,
            // Successful signup/login and authenticated writes are member events.
            member_status: userId ? 'member' : 'guest',
          },
        }],
      }),
      signal: AbortSignal.timeout(3000),
    });
  } catch { /* 분석 실패가 실제 사용자 동작을 막으면 안 된다 */ }
}
