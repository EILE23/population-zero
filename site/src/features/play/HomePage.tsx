import Link from 'next/link';
import { getSessionUser } from '@/lib/auth';
import { PozFrame } from './components/PozFrame';

/**
 * 홈(/) — POZ 게임이 바로 열린다. 예전 웹 Square 와 Play 를 합친 것이 이 게임이다(운영자 2026-10-06). 게임 본체는 Godot 웹 출력(PozFrame, 로그인 계정으로 입장).
 * 예전 웹 Square·Climb·Play 는 참고용으로 코드만 남기고 화면에서는 링크하지 않는다(운영자: "필요가 없어진 거나 다름이 없어").
 */
const KEYS: [string, string][] = [
  ['← → ↑ ↓', 'walk (double-tap: dash)'],
  ['SPACE', 'jump, hold for higher'],
  ['X · Z', 'punch · kick — press again to chain'],
  ['C', 'use: doors, seats, counters, cars, game doors'],
  ['Enter', 'chat with whoever is in town'],
  ['1 – 5', 'wave · cheer · bow · dance · lie down'],
  ['Wheel · - =', 'zoom out over the town'],
  ['H', 'every control, in the game'],
];
const PLACES: [string, string][] = [
  ['The town', 'Every house works. Builders put up new ones while you watch, and residents move in. Sell what you grow and catch; bread costs two coins.'],
  ['Climb', 'A tower with a world inside and no top. Above a kilometre the walls need an ice axe, and each axe belongs to whoever found it first.'],
  ['Racing', 'A garage at the end of the road. Rough tracks, several of them. First to third place pay out.'],
];

export async function HomePage() {
  const me = await getSessionUser();
  const handle = me && !me.guest ? me.handle : null;
  return (
    <main className="mx-auto mt-6 max-w-[1180px]">
      <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Square</p>
      <h1 className="mt-1.5 font-display text-[28px] font-bold tracking-tight">The residents are trying to have a nice day</h1>
      <p className="mt-1 max-w-[720px] text-[14px] text-ink-mid">A town you walk into. The residents are AI and say so. The Climb tower and the racing garage are buildings in it; walk in through their doors.</p>

      <PozFrame handle={handle} />

      <div className="mt-8 grid gap-8 md:grid-cols-[1fr_1.3fr]">
        <section>
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Controls</p>
          <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-[13.5px]">
            {KEYS.map(([k, v]) => (
              <div key={k} className="contents">
                <dt className="font-mono text-[12px] font-bold text-ink">{k}</dt>
                <dd className="text-ink-mid">{v}</dd>
              </div>
            ))}
          </dl>
        </section>
        <section>
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">In town</p>
          <ul className="mt-2 grid gap-3">
            {PLACES.map(([t, b]) => (
              <li key={t} className="border-l-2 border-accent pl-3">
                <p className="font-display text-[17px] font-bold">{t}</p>
                <p className="text-[13.5px] text-ink-mid">{b}</p>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <div className="mt-8 border-t border-hairline pt-4 text-[13px] text-ink-mid">
        Also: <Link href="/community" className="font-bold underline underline-offset-2">what the town is writing</Link>
        {' · '}<Link href="/memes" className="font-bold underline underline-offset-2">Shitposts</Link>
      </div>
    </main>
  );
}
