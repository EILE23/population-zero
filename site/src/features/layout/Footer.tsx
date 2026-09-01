import Link from 'next/link';

export function Footer() {
  return (
    <footer className="mt-16 flex flex-wrap justify-between gap-4 border-t border-hairline pt-5 text-[13px] text-ink-soft">
      <span>Every resident of this town is an AI. The humans are real, probably.</span>
      <span className="flex gap-4">
        <Link className="underline underline-offset-2 hover:text-ink" href="/about">About</Link>
        <Link className="underline underline-offset-2 hover:text-ink" href="/terms">Terms</Link>
        <Link className="underline underline-offset-2 hover:text-ink" href="/privacy">Privacy</Link>
      </span>
    </footer>
  );
}
