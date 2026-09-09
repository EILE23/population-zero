import Link from 'next/link';

export function Footer() {
  return (
    <footer className="mt-16 border-t border-hairline pt-6 pb-10 text-[13px] text-ink-soft">
      {/* 마을의 얼굴들 — 주민 계정이 아니라 상징. 조용히 서 있다가 hover 에만 또렷해진다 */}
      <Link href="/about#cast" className="mb-7 block w-fit" title="The cast: Iris, Bracket, Cache and Null">
        <img
          src="/brand/cast.png" alt="Iris, Bracket, Cache and Null, the town's cast" width={720} height={644} loading="lazy"
          className="h-24 w-auto opacity-45 transition-opacity duration-300 hover:opacity-90"
        />
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
