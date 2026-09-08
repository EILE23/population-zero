// 애드센스 감시: 구글 ads.txt 크롤러가 실제로 다녀갔는지 CF 로그에서 확인해 기록한다.
// 순찰(90분 간격)마다 실행 — 첫 방문이 잡히는 순간이 "찾을 수 없음" 라벨 해소의 신호탄이다.
// 토큰: env CF_OPS_TOKEN (population.town 존 Analytics Read)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';

const TOKEN = process.env.CF_OPS_TOKEN;
if (!TOKEN) { console.error('adsense-watch: no CF_OPS_TOKEN, skipping'); process.exit(0); }
const ZONE = 'ad96c14729f6558562751461a818849b';
const FILE = new URL('./adsense-watch.json', import.meta.url);

const now = new Date();
const since = new Date(now.getTime() - 4 * 3600e3); // 순찰 간격 90분 + 여유
const iso = (d) => d.toISOString().slice(0, 19) + 'Z';

const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
  method: 'POST',
  headers: { authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
  body: JSON.stringify({
    query: `{ viewer { zones(filter:{zoneTag:"${ZONE}"}) {
      httpRequestsAdaptiveGroups(filter:{clientRequestPath:"/ads.txt", datetime_geq:"${iso(since)}", datetime_leq:"${iso(now)}"}, limit:50, orderBy:[datetimeMinute_DESC]) {
        count dimensions { datetimeMinute clientCountryName edgeResponseStatus userAgent }
      } } } }`,
  }),
});
const data = await res.json();
const rows = data?.data?.viewer?.zones?.[0]?.httpRequestsAdaptiveGroups ?? [];

// 진짜 구글 크롤러만: Google 계열 UA이면서 KR(우리 검증 트래픽) 제외
const googleHits = rows.filter((r) => {
  const ua = r.dimensions.userAgent || '';
  return /google|mediapartners|adsbot/i.test(ua) && r.dimensions.clientCountryName !== 'KR';
});

const state = existsSync(FILE) ? JSON.parse(readFileSync(FILE, 'utf8')) : { last_google_fetch: null, events: [] };
state.last_check = iso(now);
if (googleHits.length > 0) {
  const hit = googleHits[0].dimensions;
  state.last_google_fetch = hit.datetimeMinute;
  state.events.push({ at: hit.datetimeMinute, ua: hit.userAgent.slice(0, 80), status: hit.edgeResponseStatus, country: hit.clientCountryName });
  state.events = state.events.slice(-20);
  console.error(`🔔 ADSENSE-WATCH: Google fetched /ads.txt at ${hit.datetimeMinute} (${hit.edgeResponseStatus}, ${hit.userAgent.slice(0, 50)}) — the "not found" label should clear soon.`);
} else {
  console.error(`adsense-watch: no Google /ads.txt fetch in last 4h (last known: ${state.last_google_fetch ?? 'never'})`);
}
writeFileSync(FILE, JSON.stringify(state, null, 2));
