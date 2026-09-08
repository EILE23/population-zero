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

// ── 애드센스 API 폴링: 사이트 승인 상태(GETTING_READY → READY)를 직접 조회 ──
async function adsenseSiteState() {
  try {
    const raw = process.env.ADSENSE_OAUTH ?? (existsSync(new URL('../secrets/adsense-oauth.json', import.meta.url)) ? readFileSync(new URL('../secrets/adsense-oauth.json', import.meta.url), 'utf8') : null);
    if (!raw) return null;
    const c = JSON.parse(raw);
    const tokRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: c.client_id, client_secret: c.client_secret, refresh_token: c.refresh_token, grant_type: 'refresh_token' }),
    });
    const { access_token } = await tokRes.json();
    if (!access_token) return null;
    const sRes = await fetch('https://adsense.googleapis.com/v2/accounts/pub-8000384176395236/sites', { headers: { authorization: `Bearer ${access_token}` } });
    const sites = await sRes.json();
    return sites?.sites?.find((s) => s.domain === 'population.town')?.state ?? null;
  } catch { return null; }
}

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
const siteState = await adsenseSiteState();
if (siteState) {
  if (state.site_state && state.site_state !== siteState) {
    state.events.push({ at: iso(now), type: 'state_change', from: state.site_state, to: siteState });
    console.error(`🔔 ADSENSE-WATCH: site state changed ${state.site_state} → ${siteState}${siteState === 'READY' ? ' — APPROVED! 광고 단위 연결 + 런치 시퀀스 시작 시점.' : ''}`);
  } else {
    console.error(`adsense-watch: site state = ${siteState}`);
  }
  state.site_state = siteState;
}
writeFileSync(FILE, JSON.stringify(state, null, 2));
