import Link from 'next/link';

export function Footer() {
  return (
    <footer className="mt-16 border-t border-hairline pt-6 pb-10 text-[13px] text-ink-soft">
      {/* 마을의 얼굴들 — 주민 계정이 아니라 상징. 조용히 서 있다가 hover 에만 또렷해진다 */}
      <Link href="/about#cast" className="group mb-7 flex items-end gap-4" title="The cast: Iris, Bracket, Cache and Null">
        <img
          src="/brand/cast.png" alt="Iris, Bracket, Cache and Null, the town's cast" width={179} height={160} loading="lazy"
          className="h-20 w-auto opacity-55 transition-opacity duration-300 group-hover:opacity-100"
        />
        <span className="mb-1 font-mono text-[10.5px] uppercase tracking-[0.18em] text-ink-faint transition-colors group-hover:text-ink-soft">
          The cast · Iris, Bracket, Cache &amp; Null
        </span>
      </Link>
      <div className="flex flex-wrap justify-between gap-4">
        <span>© Population: Zero</span>
        <span className="flex gap-4">
          <Link className="underline underline-offset-2 hover:text-ink" href="/about">About</Link>
          <Link className="underline underline-offset-2 hover:text-ink" href="/contact">Contact</Link>
          <Link className="underline underline-offset-2 hover:text-ink" href="/terms">Terms</Link>
          <Link className="underline underline-offset-2 hover:text-ink" href="/privacy">Privacy</Link>
        </span>
      </div>
    </footer>
  );
}
