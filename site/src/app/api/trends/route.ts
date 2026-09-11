import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';

type TrendRow = {
  id: number;
  source: string;
  kind: 'keyword' | 'news' | 'video' | 'reading';
  region: string | null;
  lang: string;
  topic: string | null;
  title: string;
  summary: string | null;
  source_name: string | null;
  url: string | null;
  image: string | null;
  score: number;
  rank: number;
  collected_at: string;
};

/**
 * 우리가 직접 수집하는 나라가 아니면, **같은 말을 쓰는 나라**의 피드를 대신 보여준다.
 * 대륙으로 묶지 않는 이유: 대륙이 같다고 읽는 언어가 같지 않다.
 * 오스트리아 사람에게 독일 피드는 읽히지만, 베트남 사람에게 한국어 피드는 글자조차 안 읽힌다.
 */
const READS_LIKE: Record<string, string> = {
  AT: 'DE', CH: 'DE', LI: 'DE',
  BE: 'FR', LU: 'FR', MC: 'FR', SN: 'FR', CI: 'FR', CM: 'FR',
  PT: 'BR', AO: 'BR', MZ: 'BR',
  AR: 'MX', CL: 'MX', CO: 'MX', PE: 'MX', ES: 'MX', VE: 'MX', EC: 'MX', UY: 'MX', BO: 'MX', PY: 'MX', CR: 'MX', GT: 'MX', DO: 'MX',
  IE: 'GB', NZ: 'AU', CA: 'US', ZA: 'GB', SG: 'GB', PH: 'US',
  MY: 'ID', BN: 'ID',
  KE: 'NG', GH: 'NG', UG: 'NG', TZ: 'NG',
  PK: 'IN', BD: 'IN', LK: 'IN', NP: 'IN',
};

/**
 * 우리가 실제로 나라별 소스를 갖고 있는 곳.
 * 여기 없는 나라에는 그 나라 이름을 내걸지 않는다 — 없는 걸 있는 척하지 않기 위해.
 */
const COVERED = new Set(['US', 'GB', 'KR', 'JP', 'IN', 'BR', 'DE', 'FR', 'MX', 'AU', 'ID', 'NG']);

/** 그 나라에서 읽히는 언어 — 전세계 항목을 섞을 때 언어가 맞는 것만 고르려고 */
const LANG_OF: Record<string, string> = {
  US: 'en', GB: 'en', AU: 'en', IN: 'en', NG: 'en',
  KR: 'ko', JP: 'ja', DE: 'de', FR: 'fr', BR: 'pt', MX: 'es', ID: 'id',
};

/**
 * 이 사람이 실제로 고른 것들 — 분류·매체별 가중치.
 * 누른 것(open)은 스쳐 지나간 것(view)보다 훨씬 강한 신호라 무게가 다르다.
 * 최근 2주만 본다: 취향은 변하고, 한 달 전에 한 번 누른 것이 오늘 화면을 지배하면 안 된다.
 */
type Affinity = { topic: Map<string, number>; source: Map<string, number>; kind: Map<string, number> };

async function loadAffinity(db: D1Database, userId: number | null, anon: string | null): Promise<Affinity> {
  const empty: Affinity = { topic: new Map(), source: new Map(), kind: new Map() };
  if (!userId && !anon) return empty;
  const { results } = await db.prepare(
    `SELECT topic, source, kind, action, COUNT(*) AS n
     FROM trend_events
     WHERE ${userId ? 'user_id = ?' : 'anon = ?'} AND created_at > datetime('now','-14 days')
     GROUP BY topic, source, kind, action`,
  ).bind(userId ?? anon).all<{ topic: string | null; source: string | null; kind: string | null; action: string; n: number }>();

  const bump = (m: Map<string, number>, k: string | null, v: number) => {
    if (k) m.set(k, (m.get(k) ?? 0) + v);
  };
  for (const r of results) {
    const w = (r.action === 'open' ? 3 : 0.4) * r.n;
    bump(empty.topic, r.topic, w);
    bump(empty.source, r.source, w);
    bump(empty.kind, r.kind, w);
  }
  return empty;
}

/** 한쪽으로 쏠리지 않게 로그로 누른 배수 — 최대 2배까지만 밀어준다 */
function affinityBoost(t: TrendRow, a: Affinity): number {
  const score = (a.topic.get(t.topic ?? '') ?? 0) + (a.source.get(t.source_name ?? '') ?? 0) * 0.6 + (a.kind.get(t.kind) ?? 0) * 0.4;
  if (score <= 0) return 1;
  return Math.min(2, 1 + Math.log10(1 + score) / 2);
}

/**
 * 신선도 × 원본 순위 × 세기.
 * 뉴스는 시간이 전부라 6시간이면 절반으로 죽고, 원본 매체가 위에 올린 것은 위로,
 * 조회수처럼 세기가 있는 항목은 로그로 눌러 한 개가 화면을 독점하지 않게 한다.
 */
function rank(t: TrendRow, now: number): number {
  const hours = Math.max(0, (now - Date.parse(t.collected_at.replace(' ', 'T') + 'Z')) / 36e5);
  const freshness = Math.pow(0.5, hours / 6);
  const position = 1 / (1 + t.rank * 0.35);
  const strength = t.score > 0 ? 1 + Math.log10(1 + t.score) / 6 : 1;
  // 사진과 요약이 붙은 항목이 화면에서 훨씬 잘 읽힌다 — 같은 값이면 그쪽을 위로
  const rendered = (t.image ? 1.25 : 1) * (t.summary ? 1.15 : 1);
  return freshness * position * strength * rendered;
}

/**
 * Today — 지금 이 사람의 나라에서 일어나는 일.
 * 런타임에 모델을 부르지 않는다: 순찰이 하루 여덟 번 적재해 둔 것을 고르고 줄 세울 뿐이다.
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const asked = (url.searchParams.get('country') || request.headers.get('cf-ipcountry') || '').toUpperCase();
  const kind = url.searchParams.get('kind');
  const topic = url.searchParams.get('topic');
  const offset = Math.max(0, Number(url.searchParams.get('offset')) || 0);
  const limit = Math.min(30, Math.max(1, Number(url.searchParams.get('limit')) || 20));

  // 직접 수집하는 나라면 그대로, 아니면 같은 말을 쓰는 나라의 피드로
  const region = COVERED.has(asked) ? asked : (READS_LIKE[asked] && COVERED.has(READS_LIKE[asked]) ? READS_LIKE[asked] : null);
  const lang = region ? LANG_OF[region] : 'en';

  const user = await getSessionUser();
  const anon = url.searchParams.get('anon');

  const db = await getDb();
  const where = [`collected_at > datetime('now','-2 days')`];
  const binds: (string | number)[] = [];
  // 나라가 정해졌으면 그 나라 것 + 그 언어의 전세계 항목만. 미국 사용자 화면에 한국어가 섞이지 않는다.
  if (region) { where.push(`(region = ? OR (region IS NULL AND lang = ?))`); binds.push(region, lang); }
  else { where.push(`(region IS NULL AND lang = 'en')`); }
  if (kind) { where.push(`kind = ?`); binds.push(kind); }
  if (topic) { where.push(`topic = ?`); binds.push(topic); }

  // 랭킹은 SQL 로 표현하기 어려워 후보를 넉넉히 읽고 여기서 줄 세운다.
  // 사흘치라 나라당 수백 건 규모 — 무한 스크롤이 계속 새 항목을 집어올 수 있을 만큼.
  const { results } = await db.prepare(
    `SELECT * FROM trends WHERE ${where.join(' AND ')} ORDER BY collected_at DESC LIMIT 900`,
  ).bind(...binds).all<TrendRow>();

  const now = Date.now();
  const affinity = await loadAffinity(db, user?.id ?? null, anon);
  // 한 매체가 연달아 나오지 않게 — 같은 출처는 세 칸 간격을 두고 다시 등장시킨다.
  // 완전히 막지 않는 이유: 끝없이 내려가는 화면이라 재고를 버리면 금방 바닥난다.
  const ranked = results
    .map((t) => ({ t, r: rank(t, now) * affinityBoost(t, affinity) }))
    .sort((a, b) => b.r - a.r);
  const woven: typeof ranked = [];
  const pending = [...ranked];
  while (pending.length) {
    const recent = woven.slice(-3).map((x) => x.t.source);
    const i = pending.findIndex((x) => !recent.includes(x.t.source));
    woven.push(...pending.splice(i === -1 ? 0 : i, 1));
  }

  const page = woven.slice(offset, offset + limit);
  const items = page
    .map(({ t }) => ({
      id: t.id,
      kind: t.kind,
      title: t.title,
      summary: t.summary,
      source: t.source_name,
      url: t.url,
      image: t.image,
      topic: t.topic,
      collected_at: t.collected_at,
    }));

  return Response.json(
    {
      country: asked || null, region, lang, covered: region != null, items,
      /** 더 내려갈 게 남았는지 — 앱의 무한 스크롤이 이걸 보고 멈춘다 */
      hasMore: offset + limit < woven.length,
      total: woven.length,
      /** 개인화가 켜졌는지 — 아직 기록이 없으면 모두 같은 순서를 본다 */
      personalized: affinity.topic.size > 0,
    },
    // 개인화된 응답이라 공유 캐시에 넣으면 남의 취향이 섞인다
    { headers: { 'cache-control': 'private, max-age=60' } },
  );
}
