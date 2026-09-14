// GA4 트래픽 리포트: 채널·국가·인기 페이지를 ga-report.json으로 저장 (gsc-report와 짝)
// 키: env GSC_SA_KEY(JSON 문자열, CI) 또는 secrets/gsc-sa.json(로컬) — 같은 서비스 계정, analytics.readonly
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createSign } from 'node:crypto';

const PROPERTY = 'properties/552639891';
const keyPath = new URL('../secrets/gsc-sa.json', import.meta.url);
const sa = process.env.GSC_SA_KEY ? JSON.parse(process.env.GSC_SA_KEY)
  : existsSync(keyPath) ? JSON.parse(readFileSync(keyPath, 'utf8'))
  : null;
if (!sa) { console.error('ga-report: no service account key, skipping'); process.exit(0); }

const b64 = (s) => Buffer.from(s).toString('base64url');
async function getToken() {
  const now = Math.floor(Date.now() / 1000);
  const hdr = b64(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const clm = b64(JSON.stringify({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/analytics.readonly', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 }));
  const sig = createSign('RSA-SHA256').update(`${hdr}.${clm}`).sign(sa.private_key).toString('base64url');
  const d = await (await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${hdr}.${clm}.${sig}`,
  })).json();
  if (!d.access_token) throw new Error('ga token: ' + JSON.stringify(d).slice(0, 150));
  return d.access_token;
}

async function report(token, body) {
  const d = await (await fetch(`https://analyticsdata.googleapis.com/v1beta/${PROPERTY}:runReport`, {
    method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify(body),
  })).json();
  if (d.error) throw new Error(`ga ${d.error.status}: ${(d.error.message || '').slice(0, 120)}`);
  return d.rows ?? [];
}

const token = await getToken();
// 유입원별 깔때기 — 광고·커뮤니티 글 등 유입을 넣을 때 "클릭이 글이 됐는가"를 보는 표.
// 서버 이벤트(sign_up·post_create·comment_create)는 브라우저의 client/session id 를 물고 나가므로 세션 유입원에 붙는다.
const FUNNEL_EVENTS = ['sign_up', 'post_create', 'comment_create'];
const [channels, countries, pages, retention, funnelSessions, funnelEvents] = await Promise.all([
  report(token, { dateRanges: [{ startDate: '6daysAgo', endDate: 'today' }], dimensions: [{ name: 'sessionDefaultChannelGroup' }], metrics: [{ name: 'sessions' }, { name: 'activeUsers' }, { name: 'averageSessionDuration' }] }),
  report(token, { dateRanges: [{ startDate: 'yesterday', endDate: 'today' }], dimensions: [{ name: 'country' }], metrics: [{ name: 'activeUsers' }, { name: 'averageSessionDuration' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 8 }),
  report(token, { dateRanges: [{ startDate: '6daysAgo', endDate: 'today' }], dimensions: [{ name: 'pagePath' }], metrics: [{ name: 'screenPageViews' }], orderBys: [{ metric: { metricName: 'screenPageViews' }, desc: true }], limit: 15 }),
  // 일별 신규/재방문 — 리텐션이 살아나는지 순찰마다 추적
  report(token, { dateRanges: [{ startDate: '6daysAgo', endDate: 'today' }], dimensions: [{ name: 'date' }, { name: 'newVsReturning' }], metrics: [{ name: 'activeUsers' }, { name: 'averageSessionDuration' }] }),
  report(token, { dateRanges: [{ startDate: '6daysAgo', endDate: 'today' }], dimensions: [{ name: 'sessionSourceMedium' }, { name: 'sessionCampaignName' }], metrics: [{ name: 'sessions' }, { name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'sessions' }, desc: true }], limit: 25 }),
  report(token, { dateRanges: [{ startDate: '6daysAgo', endDate: 'today' }], dimensions: [{ name: 'sessionSourceMedium' }, { name: 'sessionCampaignName' }, { name: 'eventName' }], metrics: [{ name: 'eventCount' }],
    dimensionFilter: { filter: { fieldName: 'eventName', inListFilter: { values: FUNNEL_EVENTS } } }, limit: 200 }),
]);

// 유입원 × 캠페인 한 줄에 세션과 세 이벤트를 붙인다
const funnel = new Map();
const keyOf = (r) => `${r.dimensionValues[0].value} · ${r.dimensionValues[1].value}`;
for (const r of funnelSessions) {
  funnel.set(keyOf(r), { source: r.dimensionValues[0].value, campaign: r.dimensionValues[1].value, sessions: +r.metricValues[0].value, users: +r.metricValues[1].value, sign_up: 0, post_create: 0, comment_create: 0 });
}
for (const r of funnelEvents) {
  const row = funnel.get(keyOf(r));
  if (row) row[r.dimensionValues[2].value] = +r.metricValues[0].value;
}

const byDay = {};
for (const r of retention) {
  const [date, kind] = [r.dimensionValues[0].value, r.dimensionValues[1].value];
  if (kind !== 'new' && kind !== 'returning') continue;
  (byDay[date] ??= { date, new: 0, returning: 0, returning_avg_sec: 0 });
  byDay[date][kind] = +r.metricValues[0].value;
  if (kind === 'returning') byDay[date].returning_avg_sec = Math.round(+r.metricValues[1].value);
}

const out = {
  fetched_at: new Date().toISOString(),
  channels_7d: channels.map((r) => ({ channel: r.dimensionValues[0].value, sessions: +r.metricValues[0].value, users: +r.metricValues[1].value, avg_sec: Math.round(+r.metricValues[2].value) })),
  countries_2d: countries.map((r) => ({ country: r.dimensionValues[0].value, users: +r.metricValues[0].value, avg_sec: Math.round(+r.metricValues[1].value) })),
  top_pages_7d: pages.map((r) => ({ path: r.dimensionValues[0].value, views: +r.metricValues[0].value })),
  new_vs_returning_daily: Object.values(byDay).sort((a, b) => (a.date < b.date ? -1 : 1)),
  funnel_7d: [...funnel.values()].sort((a, b) => b.sessions - a.sessions).slice(0, 12),
};
writeFileSync(new URL('./ga-report.json', import.meta.url), JSON.stringify(out, null, 2));
console.error(`ga-report.json written: channels=${out.channels_7d.length} countries=${out.countries_2d.length} pages=${out.top_pages_7d.length}`);
