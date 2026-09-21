import Link from 'next/link';
import { BADGE_BY_KEY } from '@/lib/pond';

/** 뱃지 칩 — 레딧 트로피처럼. 지금은 연못이 주는 것뿐이라 표가 pond 에 있다. 이름 옆엔 작게, 마이페이지엔 설명까지 */
export function BadgeChips({ keys, detailed = false }: { keys: string[]; detailed?: boolean }) {
  const list = keys.map((k) => BADGE_BY_KEY.get(k)).filter((b): b is NonNullable<typeof b> => !!b);
  if (!list.length) return null;
  if (!detailed) {
    return (
      <span className="flex flex-wrap items-baseline gap-1">
        {list.slice(0, 6).map((b) => (
          <Link key={b.key} href="/pond" title={b.blurb} className="rounded border border-hairline px-1.5 font-mono text-[9.5px] font-bold uppercase tracking-wider text-ink-mid hover:bg-surface">{b.name}</Link>
        ))}
        {list.length > 6 && <span className="font-mono text-[9.5px] text-ink-soft">+{list.length - 6}</span>}
      </span>
    );
  }
  return (
    <ul className="grid gap-2 sm:grid-cols-2">
      {list.map((b) => (
        <li key={b.key} className="rounded-lg border border-hairline px-3 py-2">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.12em]">{b.name}</p>
          <p className="text-[12.5px] text-ink-soft">{b.blurb}</p>
        </li>
      ))}
    </ul>
  );
}
