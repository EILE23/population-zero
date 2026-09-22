import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { GAMES } from '@/features/games/registry';
import { MakeGame } from './components/MakeGame';
import { GameCard } from './components/GameCard';
import { ReviewGame } from './components/ReviewGame';
import { hash } from '@/lib/tower';

/**
 * /play — 놀이터. 마을이 돌리는 게임들(Climb·Square·사람이 만든 것)로 들어가는 문이고, 새 게임을 프롬프트로 만드는 곳.
 * Square 는 자가 발전하는 엔진이자 소스 — 그 모션·주민·방 위에 다른 게임들이 올라간다.
 */
interface Row { id: number; slug: string; title: string; prompt: string; status: string; note: string | null; created_at: string; built_at: string | null; maker: string; user_id: number | null }
const BUILT_IN = [
  { blurb: 'An endless tower. Charge a jump, steer in the air, stand on whoever is in the way.' },
  { blurb: 'Knock the residents over, take their things, put the things in the fountain. They chase, throw and fix.' },
];

export async function PlayPage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const signedIn = !!me && !me.guest;
  const { results: rows } = await db.prepare(`SELECT g.id, g.slug, g.title, g.prompt, g.status, g.note, g.created_at, g.built_at, g.user_id, COALESCE(u.handle, r.handle) AS maker FROM games g LEFT JOIN users u ON u.id = g.user_id LEFT JOIN residents r ON r.id = g.resident_id ORDER BY g.id DESC LIMIT 80`).all<Row>();
  const byRow = new Map(rows.map((r) => [r.slug, r]));
  const admin = !!me && !!me.is_admin;
  // 코드가 있고 만든 사람이 승인한 것만 공개(live). review 는 만든 사람(과 운영자)에게만 보인다 — 만들어지자마자 공개되던 시절엔 안 되는 게임이 걸렸다
  const live = GAMES.map((g) => ({ ...g, row: byRow.get(g.slug) })).filter((g) => g.row?.status === 'live' || (g.row?.status === 'review' && (admin || (signedIn && g.row.user_id === me!.id))));
  const queue = rows.filter((r) => r.status !== 'live' && r.status !== 'review').slice(0, 20);
  const mineToReview = signedIn ? rows.filter((r) => (admin || r.user_id === me!.id) && (r.status === 'review' || r.status === 'live') && GAMES.some((g) => g.slug === r.slug)) : [];
  const pending = signedIn ? rows.find((r) => r.user_id === me!.id && (r.status === 'queued' || r.status === 'building')) ?? null : null;

  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Playground</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">Games</h1>

        <ul className="mt-5 grid gap-3 sm:grid-cols-2">
          <GameCard href="/climb" title="Climb" blurb={BUILT_IN[0].blurb} by="the town" preview="climb" seed={me && !me.guest ? me.id : 0} />
          <GameCard href="/square" title="Square" blurb={BUILT_IN[1].blurb} by="the town" preview="square" seed={me && !me.guest ? me.id : 0} />
          {live.map((g) => (
            <GameCard key={g.slug} href={`/play/${g.slug}`} title={g.title} blurb={g.blurb} preview="game" seed={hash(g.slug) % 100000}
              by={g.row ? <><Link href={`/${g.row.maker}`} className="hover:underline">{g.row.maker}</Link>{g.row.built_at ? ` · ${g.row.built_at.slice(0, 10)}` : ''}</> : 'someone'} />
          ))}
        </ul>

        {mineToReview.length > 0 && <div className="mt-6 grid gap-3">{mineToReview.map((r) => <ReviewGame key={r.slug} slug={r.slug} title={r.title} live={r.status === 'live'} />)}</div>}

        <section className="mt-8 rounded-xl border border-hairline bg-paper p-4">
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Make a game</p>
          <h2 className="mt-1 font-display text-[20px] font-bold tracking-tight">Describe a game. It gets built.</h2>
          <p className="mt-1 text-[13px] text-ink-mid">It appears above under your handle. A few a day, in order.</p>
          <div className="mt-3">
            {signedIn ? <MakeGame pending={pending ? { slug: pending.slug, title: pending.title, status: pending.status } : null} /> : <p className="text-[13.5px] text-ink-mid"><Link href="/login?mode=signup" className="font-bold underline underline-offset-2">Log in</Link> to make one.</p>}
          </div>
        </section>

        {queue.length > 0 && (
          <section className="mt-6">
            <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Queue</p>
            <ul className="mt-2 divide-y divide-hairline text-[13.5px]">
              {queue.map((r) => (
                <li key={r.id} className="flex flex-wrap items-baseline gap-x-3 py-2">
                  <span className="font-bold">{r.title}</span>
                  <span className="font-mono text-[10.5px] text-ink-soft">by {r.maker} · {r.status}{r.status === 'failed' && r.note ? ` — ${r.note}` : ''}</span>
                  <span className="basis-full text-[12.5px] text-ink-mid">{r.prompt.length > 180 ? `${r.prompt.slice(0, 180)}…` : r.prompt}</span>
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </main>
  );
}
