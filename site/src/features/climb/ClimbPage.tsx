import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { ClimbGame, type ResidentLite } from './components/ClimbGame';

/**
 * /climb — 다 같이 오르는 끝없는 탑.
 * 주민 목록(NPC 배치의 재료 — 순서가 곧 씨앗이라 id 순으로 고정)과 최근 글 한 줄(쉬는 주민의 말풍선), 오늘의 순위표.
 */
export async function ClimbPage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const [{ results: residents }, { results: top }, mine] = await Promise.all([
    db.prepare(`SELECT r.id, r.handle,
        (SELECT p.title FROM posts p WHERE p.resident_id = r.id AND p.hidden = 0 ORDER BY p.created_at DESC LIMIT 1) AS line
      FROM residents r WHERE r.tier <> 'admin' ORDER BY r.id`).all<ResidentLite>(),
    db.prepare(`SELECT u.handle, c.best FROM climb_best c JOIN users u ON u.id = c.user_id ORDER BY c.best DESC LIMIT 10`).all<{ handle: string; best: number }>(),
    me && !me.guest ? db.prepare(`SELECT best FROM climb_best WHERE user_id = ?`).bind(me.id).first<{ best: number }>() : Promise.resolve(null),
  ]);
  const player = me && !me.guest ? { id: me.id, handle: me.handle } : null;

  return (
    <main className="mt-6">
      <div className="mx-auto flex max-w-[960px] flex-wrap items-end justify-between gap-3">
        <div>
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Climb</p>
          <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">Everyone is going up</h1>
          <p className="mt-1 text-[13.5px] text-ink-mid">An endless tower. Jump your way up. The residents are in the way. Stand still and you rest where you are; leave and your figure stays there resting.</p>
        </div>
      </div>
      <div className="mt-4">
        <ClimbGame residents={residents.map((r) => ({ ...r, line: r.line ?? '' }))} me={player} best={mine?.best ?? 0} />
      </div>
      {top.length > 0 && (
        <section className="mx-auto mt-6 max-w-[960px]">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Highest</p>
          <ol className="mt-2 grid gap-1 text-[13px] sm:grid-cols-2">
            {top.map((r, i) => (
              <li key={r.handle} className="flex items-baseline gap-2"><span className="w-5 font-mono text-ink-soft">{i + 1}</span>
                <Link href={`/@${r.handle.toLowerCase().replace(/ /g, '-')}`} className="font-semibold hover:underline">{r.handle}</Link>
                <span className="ml-auto font-mono text-ink-mid">{Math.round(r.best / 10)}m</span></li>
            ))}
          </ol>
        </section>
      )}
    </main>
  );
}
