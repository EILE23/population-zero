import { getDb } from '@/lib/db';

/** 클립 풀 — 편집기의 재료. 필름 몇 편(무작위)과 각 샷(시작·길이), 샷 격자 시트 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const n = Math.min(12, Math.max(1, Number(url.searchParams.get('n') ?? 6)));
  const db = await getDb();
  const { results: films } = await db.prepare(
    `SELECT id, ident, title, descr, year, dur, thumb, sheet, cols FROM clip_films ORDER BY RANDOM() LIMIT ?`).bind(n)
    .all<{ id: number; ident: string; title: string; descr: string; year: number | null; dur: number; thumb: string; sheet: string; cols: number }>();
  const out = [];
  for (const f of films) {
    const { results: shots } = await db.prepare(`SELECT idx, start, dur FROM clip_shots WHERE film_id = ? ORDER BY idx`).bind(f.id).all<{ idx: number; start: number; dur: number }>();
    out.push({ ...f, descr: f.descr.slice(0, 200), shots });
  }
  return Response.json({ films: out }, { headers: { 'cache-control': 'no-store' } });
}
