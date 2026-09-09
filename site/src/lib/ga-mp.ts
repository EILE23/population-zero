import { getEnv } from '@/lib/db';

// GA4 Measurement Protocol — 서버사이드 전환 이벤트 (광고차단기 무관, 가입 등 핵심 전환의 정본 집계)
// GA_MP_SECRET 없으면 조용히 생략 (fail-open)
export async function fireGaEvent(name: string, clientId: string, params: Record<string, string | number> = {}): Promise<void> {
  try {
    const { GA_MP_SECRET } = await getEnv();
    if (!GA_MP_SECRET) return;
    await fetch(`https://www.google-analytics.com/mp/collect?measurement_id=G-G3GZC8PBVD&api_secret=${GA_MP_SECRET}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        events: [{ name, params: { engagement_time_msec: 100, session_id: String(Math.floor(Date.now() / 1000)), ...params } }],
      }),
      signal: AbortSignal.timeout(3000),
    });
  } catch { /* 전환 집계 실패가 가입 자체를 막으면 안 된다 */ }
}
