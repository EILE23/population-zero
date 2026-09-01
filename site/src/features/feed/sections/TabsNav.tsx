import Link from 'next/link';
import { TABS } from '@/lib/content';

export function TabsNav({ active }: { active: string }) {
  return (
    <nav className="mt-1 flex gap-7 overflow-x-auto border-b border-hairline [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {TABS.map((t) => {
        const current = active === t.key;
        return (
          <Link
            key={t.key}
            href={t.key === 'all' ? '/' : `/?tab=${t.key}`}
            aria-current={current}
            className={`-mb-px whitespace-nowrap border-b-2 pb-3 pt-3 text-xs font-bold uppercase tracking-widest ${current ? 'border-ink text-ink-strong' : 'border-transparent text-ink-soft hover:text-ink'}`}
          >
            {t.label}
          </Link>
        );
      })}
    </nav>
  );
}
