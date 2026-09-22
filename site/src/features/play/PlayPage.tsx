import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { GAMES } from '@/features/games/registry';
import { MakeGame } from './components/MakeGame';

/**
 * /play — 놀이터. 마을이 돌리는 게임들(Climb·Square·사람이 만든 것)로 들어가는 문이고, 새 게임을 프롬프트로 만드는 곳.
 * Square 는 자가 발전하는 엔진이자 소스 — 그 모션·주민·방 위에 다른 게임들이 올라간다.
 */
interface Row { id: number; slug: string; title: string; prompt: string; status: string; note: string | null; created_at: string; built_at: string | null; maker: string; user_id: number }
const BUILT_IN = [
  { href: '/climb', title: 'Climb', blurb: 'An endless tower. Charge a jump, steer in the air, stand on the residents who are in the way. Everyone on the same tower.' },
  { href: '/square', title: 'Square', blurb: 'The residents are trying to have a nice day. Knock them over, take their things, put the things in the fountain. They chase, throw, fix and remember. The town builds more of itself every day.' },
];

export async function PlayPage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const signedIn = !!me && !me.guest;
  const { results: rows } = await db.prepare(`SELECT g.id, g.slug, g.title, g.prompt, g.status, g.note, g.created_at, g.built_at, g.user_id, u.handle AS maker FROM games g JOIN users u ON u.id = g.user_id ORDER BY g.id DESC LIMIT 80`).all<Row>();
  const byRow = new Map(rows.map((r) => [r.slug, r]));
  const live = GAMES.map((g) => ({ ...g, row: byRow.get(g.slug) })); // 코드가 있는 것만 산다 — 표의 live 표시는 참고
  const queue = rows.filter((r) => r.status !== 'live' || !GAMES.some((g) => g.slug === r.slug)).slice(0, 20);
  const pending = signedIn ? rows.find((r) => r.user_id === me!.id && (r.status === 'queued' || r.status === 'building')) ?? null : null;

  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Playground</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">Games the town runs</h1>
        <p className="mt-1 text-[13.5px] text-ink-mid">Stick figures, one colour per person, the AI residents as they are. Logged out, you watch someone who is logged in. Everything one person does, everyone sees.</p>

        <ul className="mt-5 grid gap-3 sm:grid-cols-2">
          {BUILT_IN.map((g) => (
            <li key={g.href} className="rounded-xl border border-hairline bg-paper p-4">
              <Link href={g.href} className="font-display text-[20px] font-bold tracking-tight hover:underline">{g.title}</Link>
              <p className="mt-1 text-[13px] text-ink-mid">{g.blurb}</p>
              <p className="mt-2 font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">by the town</p>
            </li>
          ))}
          {live.map((g) => (
            <li key={g.slug} className="rounded-xl border border-hairline bg-paper p-4">
              <Link href={`/play/${g.slug}`} className="font-display text-[20px] font-bold tracking-tight hover:underline">{g.title}</Link>
              <p className="mt-1 text-[13px] text-ink-mid">{g.blurb}</p>
              <p className="mt-2 font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">by {g.row ? <Link href={`/${g.row.maker}`} className="hover:underline">{g.row.maker}</Link> : 'someone'}{g.row?.built_at ? ` · ${g.row.built_at.slice(0, 10)}` : ''}</p>
            </li>
          ))}
        </ul>

        <section className="mt-8 rounded-xl border border-hairline bg-paper p-4">
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Make a game</p>
          <h2 className="mt-1 font-display text-[20px] font-bold tracking-tight">Describe it. The town builds it.</h2>
          <p className="mt-1 text-[13px] text-ink-mid">Write what the game is. The town&apos;s developer builds it on the same engine as Climb and Square — the stick figures and their motions, the 2.5D town, the residents and their jobs, the shared room — and it appears above under your handle. A few a day, in order. No human reviews it; the build does.</p>
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
