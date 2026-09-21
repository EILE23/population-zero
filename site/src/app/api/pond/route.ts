import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';
import { sameOriginOrBearer } from '@/lib/safety';
import { BADGES, BAITS, COINS, ITEM_BY_KEY, ITEM_LIST, RODS, roll, ZONES, type BaitKey, type ZoneKey } from '@/lib/pond';

/**
 * 연못 — 한 문으로 네 가지: cast(던지기: 서버가 뽑아 둔다) · land(챔질 성공: 기록·코인·뱃지) · miss · buy(낚싯대·미끼).
 * 뽑기를 서버가 하는 이유: 브라우저가 "전설 잡았다" 고 우기면 도감이 의미가 없다. 타이밍(챔질)만 브라우저 몫.
 */
interface Player { user_id: number; rod: number; coins: number; casts: number; bait: string; pending: string | null }
interface Pending { item: string; name: string; zone: ZoneKey; exp: number }

async function player(db: D1Database, uid: number): Promise<Player> {
  await db.prepare(`INSERT OR IGNORE INTO pond_players (user_id) VALUES (?)`).bind(uid).run();
  return (await db.prepare(`SELECT user_id, rod, coins, casts, bait, pending FROM pond_players WHERE user_id = ?`).bind(uid).first<Player>())!;
}
const baitOf = (p: Player): Partial<Record<BaitKey, number>> => { try { return JSON.parse(p.bait) as Partial<Record<BaitKey, number>>; } catch { return {}; } };
async function state(db: D1Database, uid: number) {
  const p = await player(db, uid);
  const [{ results: book }, { results: badges }] = await Promise.all([
    db.prepare(`SELECT item, COUNT(*) AS n FROM pond_catches WHERE user_id = ? GROUP BY item`).bind(uid).all<{ item: string; n: number }>(),
    db.prepare(`SELECT key FROM badges WHERE user_id = ?`).bind(uid).all<{ key: string }>(),
  ]);
  return { rod: p.rod, coins: p.coins, casts: p.casts, bait: baitOf(p), book: Object.fromEntries(book.map((r) => [r.item, r.n])), badges: badges.map((b) => b.key) };
}

export async function GET() {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ signedIn: false });
  return Response.json({ signedIn: true, ...(await state(await getDb(), user.id)) }, { headers: { 'cache-control': 'no-store' } });
}

export async function POST(request: Request) {
  if (!sameOriginOrBearer(request)) return Response.json({ error: 'origin' }, { status: 403 });
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ error: 'unauthorized', message: 'Log in to keep what you catch.' }, { status: 401 });
  if (await rateLimited(request, 'pond', 60, 1)) return Response.json({ error: 'rate' }, { status: 429 });
  const b = (await request.json().catch(() => ({}))) as { action?: string; zone?: unknown; bait?: unknown; what?: unknown };
  const db = await getDb();
  const p = await player(db, user.id);
  const rod = RODS[Math.min(RODS.length, Math.max(1, p.rod)) - 1];

  if (b.action === 'cast') {
    const zone = ZONES.find((z) => z.key === b.zone);
    if (!zone) return Response.json({ error: 'zone' }, { status: 400 });
    if (rod.level < zone.rod) return Response.json({ error: 'rod', message: `${zone.name} needs rod level ${zone.rod}.` }, { status: 400 });
    const bait = BAITS.find((x) => x.key === b.bait)?.key ?? null;
    const have = baitOf(p);
    if (bait && !(have[bait] ?? 0)) return Response.json({ error: 'bait', message: `No ${bait} left.` }, { status: 400 });
    // 뽑기 — 자리 표시자는 여기서 채운다
    const item = roll(Math.random, zone.key, rod, bait);
    let name = item.name;
    if (name.includes('{resident}')) { const r = await db.prepare(`SELECT handle FROM residents WHERE tier <> 'admin' ORDER BY RANDOM() LIMIT 1`).first<{ handle: string }>(); name = name.replace('{resident}', r?.handle ?? 'a resident'); }
    if (name.includes('{film}')) { const f = await db.prepare(`SELECT title, year FROM clip_films ORDER BY RANDOM() LIMIT 1`).first<{ title: string; year: number | null }>(); name = name.replace('{film}', f ? `"${f.title}" (${f.year ?? '?'})` : 'an old film'); }
    if (bait) have[bait] = (have[bait] ?? 0) - 1;
    const wait = (zone.wait[0] + Math.random() * (zone.wait[1] - zone.wait[0])) * rod.wait;
    const pending: Pending = { item: item.key, name, zone: zone.key, exp: Date.now() + (wait + 30) * 1000 };
    await db.prepare(`UPDATE pond_players SET casts = casts + 1, bait = ?, pending = ?, updated_at = datetime('now') WHERE user_id = ?`)
      .bind(JSON.stringify(have), JSON.stringify(pending), user.id).run();
    // 뭐가 물지는 안 알려준다 — 기다림과 챔질 창만
    return Response.json({ ok: true, wait: Math.round(wait * 10) / 10, window: Math.round(zone.window * rod.window * 100) / 100, bait: have });
  }

  if (b.action === 'land' || b.action === 'miss') {
    let pending: Pending | null = null;
    try { pending = p.pending ? JSON.parse(p.pending) as Pending : null; } catch { pending = null; }
    await db.prepare(`UPDATE pond_players SET pending = NULL WHERE user_id = ?`).bind(user.id).run();
    if (b.action === 'miss' || !pending || pending.exp < Date.now()) return Response.json({ ok: true, item: null, ...(await state(db, user.id)) });
    const item = ITEM_BY_KEY.get(pending.item);
    if (!item) return Response.json({ ok: true, item: null, ...(await state(db, user.id)) });
    const earned = COINS[item.rarity];
    await db.batch([
      db.prepare(`INSERT INTO pond_catches (user_id, item, name, rarity, zone) VALUES (?, ?, ?, ?, ?)`).bind(user.id, item.key, pending.name, item.rarity, pending.zone),
      db.prepare(`UPDATE pond_players SET coins = coins + ? WHERE user_id = ?`).bind(earned, user.id),
    ]);
    // 뱃지 — 이정표와 전설
    const s = await state(db, user.id);
    const total = Object.values(s.book).reduce((a, n) => a + n, 0);
    const { results: zones } = await db.prepare(`SELECT DISTINCT zone FROM pond_catches WHERE user_id = ?`).bind(user.id).all<{ zone: string }>();
    const want: string[] = ['first'];
    if (total >= 10) want.push('ten'); if (total >= 50) want.push('fifty'); if (total >= 200) want.push('two_hundred');
    if (item.rarity === 'r' || item.rarity === 'l') want.push('rare');
    if (item.rarity === 'l') want.push(`l:${item.key}`);
    if (zones.length >= ZONES.length) want.push('all_zones');
    const fresh = want.filter((k) => !s.badges.includes(k) && BADGES.some((x) => x.key === k));
    if (fresh.length) await db.batch(fresh.map((k) => db.prepare(`INSERT OR IGNORE INTO badges (user_id, key) VALUES (?, ?)`).bind(user.id, k)));
    return Response.json({ ok: true, item: { ...item, name: pending.name }, earned, newBadges: fresh, ...s, badges: [...s.badges, ...fresh] });
  }

  if (b.action === 'buy') {
    const what = String(b.what ?? '');
    if (what === 'rod') {
      const next = RODS[rod.level]; // 다음 단계
      if (!next) return Response.json({ error: 'max', message: 'That is the rod. There is no better rod.' }, { status: 400 });
      if (p.coins < next.price) return Response.json({ error: 'coins', message: `${next.name} costs ${next.price}. You have ${p.coins}.` }, { status: 400 });
      await db.prepare(`UPDATE pond_players SET rod = ?, coins = coins - ? WHERE user_id = ?`).bind(next.level, next.price, user.id).run();
      if (next.level === RODS.length) await db.prepare(`INSERT OR IGNORE INTO badges (user_id, key) VALUES (?, 'the_rod')`).bind(user.id).run();
      return Response.json({ ok: true, ...(await state(db, user.id)) });
    }
    const bait = BAITS.find((x) => x.key === what);
    if (!bait) return Response.json({ error: 'what' }, { status: 400 });
    const qty = 5, cost = bait.price * qty;
    if (p.coins < cost) return Response.json({ error: 'coins', message: `5 ${bait.name} cost ${cost}. You have ${p.coins}.` }, { status: 400 });
    const have = baitOf(p); have[bait.key] = (have[bait.key] ?? 0) + qty;
    await db.prepare(`UPDATE pond_players SET bait = ?, coins = coins - ? WHERE user_id = ?`).bind(JSON.stringify(have), cost, user.id).run();
    return Response.json({ ok: true, ...(await state(db, user.id)) });
  }
  void ITEM_LIST;
  return Response.json({ error: 'action' }, { status: 400 });
}
