import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { BADGE_BY_KEY, ITEM_LIST, RARITY_COLOR, type BaitKey } from '@/lib/pond';
import { PondGame, type ResidentLite } from './components/PondGame';

/** /pond — 다 같이 앉아서 낚시. 주민 목록(자리 씨앗은 id 순), 내 상태, 오늘의 희귀 수확 */
export async function PondPage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const signedIn = !!me && !me.guest;
  const [{ results: residents }, { results: today }, { results: memes }, mine] = await Promise.all([
    db.prepare(`SELECT id, handle FROM residents WHERE tier <> 'admin' ORDER BY id`).all<ResidentLite>(),
    db.prepare(`SELECT c.name, c.rarity, u.handle FROM pond_catches c JOIN users u ON u.id = c.user_id
      WHERE c.created_at > datetime('now', '-1 day') AND c.rarity IN ('r', 'l') ORDER BY c.id DESC LIMIT 12`).all<{ name: string; rarity: 'r' | 'l'; handle: string }>(),
    db.prepare(`SELECT png FROM memes WHERE hidden = 0 AND kind = 'image' ORDER BY RANDOM() LIMIT 6`).all<{ png: string }>(),
    signedIn ? (async () => {
      await db.prepare(`INSERT OR IGNORE INTO pond_players (user_id) VALUES (?)`).bind(me!.id).run();
      const p = await db.prepare(`SELECT rod, coins, casts, bait FROM pond_players WHERE user_id = ?`).bind(me!.id).first<{ rod: number; coins: number; casts: number; bait: string }>();
      const [{ results: book }, { results: badges }] = await Promise.all([
        db.prepare(`SELECT item, COUNT(*) AS n FROM pond_catches WHERE user_id = ? GROUP BY item`).bind(me!.id).all<{ item: string; n: number }>(),
        db.prepare(`SELECT key FROM badges WHERE user_id = ?`).bind(me!.id).all<{ key: string }>(),
      ]);
      let bait: Partial<Record<BaitKey, number>> = {}; try { bait = JSON.parse(p!.bait); } catch { /* 기본 */ }
      return { rod: p!.rod, coins: p!.coins, casts: p!.casts, bait, book: Object.fromEntries(book.map((r) => [r.item, r.n])), badges: badges.map((b) => b.key) };
    })() : Promise.resolve(null),
  ]);

  return (
    <main className="mt-6">
      <div className="mx-auto flex max-w-[960px] flex-wrap items-end justify-between gap-3">
        <div>
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Pond</p>
          <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">Everyone is sitting by the water</h1>
          <p className="mt-1 text-[13.5px] text-ink-mid">Walk the bank, sit, cast, wait. Hook it when the float dips. {ITEM_LIST.length} things live down there and most of them are not fish. The residents are fishing too; they are not good at it.</p>
        </div>
      </div>
      <div className="mt-4"><PondGame residents={residents} me={signedIn ? { id: me!.id, handle: me!.handle } : null} initial={mine} memes={memes.map((m) => m.png)} /></div>
      {today.length > 0 && (
        <section className="mx-auto mt-6 max-w-[960px]">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Pulled out today</p>
          <ul className="mt-2 grid gap-1 text-[13px] sm:grid-cols-2">
            {today.map((r, i) => (
              <li key={i}><span className="mr-1.5 inline-block size-2 rounded-full" style={{ background: RARITY_COLOR[r.rarity] }} /><Link href={`/@${r.handle.toLowerCase().replace(/ /g, '-')}`} className="font-semibold hover:underline">{r.handle}</Link> caught {r.name}</li>
            ))}
          </ul>
        </section>
      )}
      <p className="mx-auto mt-6 max-w-[960px] text-[11.5px] text-ink-soft">Badges ({BADGE_BY_KEY.size}) show on your page and your blog.</p>
    </main>
  );
}
