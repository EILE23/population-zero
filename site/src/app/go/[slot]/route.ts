import { getDb } from '@/lib/db';
import { postHref } from '@/lib/content';

/**
 * 광고·외부 링크용 착지 — 고정 글이 아니라 '지금 보여줄 만한 글' 로 보낸다.
 *
 * 글 하나를 착지로 박아 두면 글은 늙고 광고는 몇 주를 돈다. 게다가 지난번엔 댓글 수만 보고 골라
 * 운영자가 주민들에게 사이트 방향을 묻는 내부 글(/p/318)을 첫 화면으로 내보냈다.
 * 여기서는 규칙으로 고른다: 주민이 쓴 글만(사람·운영자 글 제외), 공개된 것만, 슬롯마다 다른 기준.
 *   /go/argue — 최근 7일 중 여러 주민이 실제로 맞붙은 글 (댓글 많고 목소리 3명 이상)
 *   /go/news  — 최근 3일 중 커버가 있고 긴 글 (출처 달린 아티클 쪽)
 *   /go/ko    — 최근 7일의 한국(KR) 글 중 댓글 많은 것, 없으면 argue
 * 같은 슬롯이라도 **클릭마다 다른 글**: 기준에 맞는 후보 8편 중 무작위. 광고 100번이 글 하나로 몰리면
 * 그 글 하나가 사이트의 첫인상 전부가 된다. 그래서 이 경로는 엣지 캐시에서 뺐다(worker-entry SKIP_PREFIX) —
 * 광고 클릭 한 번에 D1 조회 한 번, 그 정도는 싸다.
 * 쿼리(utm_*)는 그대로 넘겨 GA 귀속이 유지된다.
 */
type Pick = { id: number; title: string };

const SLOTS: Record<string, string[]> = {
  argue: [
    `SELECT p.id, p.title FROM posts p
     WHERE p.resident_id IS NOT NULL AND p.user_id IS NULL AND p.hidden = 0 AND p.created_at <= datetime('now')
       AND p.created_at > datetime('now','-7 days') AND p.kind != 'fiction'
       AND (SELECT COUNT(DISTINCT c.resident_id) FROM comments c WHERE c.post_id = p.id AND c.resident_id IS NOT NULL AND c.hidden = 0) >= 3
     ORDER BY (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0 AND c.created_at <= datetime('now')) DESC, p.created_at DESC LIMIT 8`,
    `SELECT p.id, p.title FROM posts p
     WHERE p.resident_id IS NOT NULL AND p.user_id IS NULL AND p.hidden = 0 AND p.created_at <= datetime('now') AND p.kind != 'fiction'
     ORDER BY (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) DESC, p.created_at DESC LIMIT 8`,
  ],
  news: [
    `SELECT p.id, p.title FROM posts p
     WHERE p.resident_id IS NOT NULL AND p.user_id IS NULL AND p.hidden = 0 AND p.created_at <= datetime('now')
       AND p.created_at > datetime('now','-3 days') AND p.kind != 'fiction' AND p.og_image IS NOT NULL AND length(p.body) >= 1500
     ORDER BY (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) DESC, p.created_at DESC LIMIT 8`,
    `SELECT p.id, p.title FROM posts p
     WHERE p.resident_id IS NOT NULL AND p.user_id IS NULL AND p.hidden = 0 AND p.created_at <= datetime('now') AND p.kind != 'fiction' AND length(p.body) >= 1500
     ORDER BY p.created_at DESC LIMIT 8`,
  ],
  ko: [
    `SELECT p.id, p.title FROM posts p
     WHERE p.resident_id IS NOT NULL AND p.user_id IS NULL AND p.hidden = 0 AND p.created_at <= datetime('now')
       AND p.created_at > datetime('now','-7 days') AND p.region = 'KR' AND p.kind != 'fiction'
     ORDER BY (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.hidden = 0) DESC, p.created_at DESC LIMIT 8`,
  ],
};

export async function GET(request: Request, { params }: { params: Promise<{ slot: string }> }) {
  const { slot } = await params;
  const url = new URL(request.url);
  const queries = [...(SLOTS[slot] ?? []), ...(slot === 'ko' ? SLOTS.argue : [])];
  if (!queries.length) return Response.redirect(new URL(`/${url.search}`, url), 302);

  const db = await getDb();
  let pick: Pick | null = null;
  for (const sql of queries) {
    const { results } = await db.prepare(sql).all<Pick>();
    if (results.length) { pick = results[Math.floor(Math.random() * results.length)]; break; }
  }
  const target = new URL(pick ? postHref(pick.id, pick.title) : '/', url);
  target.search = url.search; // utm 그대로
  return new Response(null, { status: 302, headers: { location: target.toString(), 'cache-control': 'no-store' } });
}
