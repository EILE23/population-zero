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
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/webmasters',
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

// 색인률 표본 검사: 사이트맵의 최신 글 15개를 URL Inspection API로 확인
async function inspectCoverage(token, siteUrl) {
  try {
    const xml = await (await fetch('https://population.town/sitemap.xml')).text();
    // 사이트맵 URL 은 이제 /p/<id>/<slug> 형태다. 예전 정규식은 /p/숫자 로 끝나는 것만 인정해서
    // 표본이 0개가 됐고, 0개를 "색인 0%" 가 아니라 그냥 조용히 넘겼다.
    const urls = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)]
      .map((m) => m[1].trim())
      .filter((u) => /^https:\/\/population\.town\/p\/\d+(\/|$)/.test(u))
      .slice(0, 15);
    if (!urls.length) return { checked: 0, indexed: 0, status: 'no_data', note: 'sitemap 에서 글 URL 을 찾지 못함' };
    const results = [];
    for (const u of urls) {
      const res = await fetch('https://searchconsole.googleapis.com/v1/urlInspection/index:inspect', {
        method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ inspectionUrl: u, siteUrl }),
      });
      if (!res.ok) { results.push({ url: u, verdict: `HTTP ${res.status}` }); continue; }
      const d = await res.json();
      results.push({ url: u, verdict: d.inspectionResult?.indexStatusResult?.coverageState ?? '?' });
    }
    // coverageState 는 문장이다. "Crawled - currently not indexed" 에도 'indexed' 가 들어 있어서
    // 단순 포함 검사는 미색인을 색인 성공으로 센다. 부정 문구를 먼저 걸러낸다.
    const isIndexed = (v) => /indexed/i.test(v) && !/not indexed|excluded|error|not found|blocked|redirect|duplicate|alternate/i.test(v);
    const indexed = results.filter((r) => isIndexed(r.verdict)).length;
    const notIndexed = results.filter((r) => !isIndexed(r.verdict)).map((r) => r.verdict);
    return {
      checked: results.length,
      indexed,
      status: results.length ? 'ok' : 'no_data',
      not_indexed_reasons: [...new Set(notIndexed)].slice(0, 6),
      details: results,
    };
  } catch (e) { return { error: String(e).slice(0, 120) }; }
}
const coverage = await inspectCoverage(token, site);

const report = {
  fetched_at: new Date().toISOString(), site, period_days: 7,
  index_coverage: coverage,
  top_queries: queries.map((r) => ({ query: r.keys[0], impressions: r.impressions, clicks: r.clicks, position: Math.round(r.position * 10) / 10 })),
  top_pages: pages.map((r) => ({ page: r.keys[0], impressions: r.impressions, clicks: r.clicks })),
};
writeFileSync(new URL('./gsc-report.json', import.meta.url), JSON.stringify(report, null, 2));
console.error(`gsc-report.json written: queries=${report.top_queries.length} pages=${report.top_pages.length}`);
