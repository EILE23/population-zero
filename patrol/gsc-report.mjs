// GSC 검색어 리포트: 최근 7일 유입 검색어·페이지를 뽑아 gsc-report.json으로 저장.
// 순찰이 이걸 읽고 "검색 수요가 있는 주제"를 콘텐츠 전략에 반영한다 (SEO 자기학습 루프).
// 키: env GSC_SA_KEY(JSON 문자열, CI) 또는 secrets/gsc-sa.json(로컬).
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createSign } from 'node:crypto';

const SITE = 'sc-domain:population.town'; // 도메인 속성이 아니면 'https://population.town/'로 폴백
const keyPath = new URL('../secrets/gsc-sa.json', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const sa = process.env.GSC_SA_KEY ? JSON.parse(process.env.GSC_SA_KEY)
  : existsSync(keyPath) ? JSON.parse(readFileSync(keyPath, 'utf8'))
  : null;
if (!sa) { console.error('no service account key (GSC_SA_KEY env or secrets/gsc-sa.json)'); process.exit(1); }

// 서비스 계정 JWT → 액세스 토큰
const b64url = (s) => Buffer.from(s).toString('base64url');
async function getToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/webmasters.readonly',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const signer = createSign('RSA-SHA256');
  signer.update(`${header}.${claims}`);
  const sig = signer.sign(sa.private_key).toString('base64url');
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${header}.${claims}.${sig}`,
  });
  const d = await res.json();
  if (!d.access_token) throw new Error('token: ' + JSON.stringify(d).slice(0, 200));
  return d.access_token;
}

async function query(token, site, dimensions) {
  const end = new Date().toISOString().slice(0, 10);
  const start = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10);
  const res = await fetch(`https://www.googleapis.com/webmasters/v3/sites/${encodeURIComponent(site)}/searchAnalytics/query`, {
    method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ startDate: start, endDate: end, dimensions, rowLimit: 50 }),
  });
  if (!res.ok) throw new Error(`${site} ${dimensions}: HTTP ${res.status} ${(await res.text()).slice(0, 150)}`);
  return (await res.json()).rows ?? [];
}

const token = await getToken();
let site = SITE, queries, pages;
try {
  queries = await query(token, site, ['query']);
  pages = await query(token, site, ['page']);
} catch (e) {
  site = 'https://population.town/'; // URL 접두어 속성 폴백
  queries = await query(token, site, ['query']);
  pages = await query(token, site, ['page']);
}

const report = {
  fetched_at: new Date().toISOString(), site, period_days: 7,
  top_queries: queries.map((r) => ({ query: r.keys[0], impressions: r.impressions, clicks: r.clicks, position: Math.round(r.position * 10) / 10 })),
  top_pages: pages.map((r) => ({ page: r.keys[0], impressions: r.impressions, clicks: r.clicks })),
};
writeFileSync(new URL('./gsc-report.json', import.meta.url), JSON.stringify(report, null, 2));
console.error(`gsc-report.json written: queries=${report.top_queries.length} pages=${report.top_pages.length}`);
