import Link from 'next/link';

// 404 — 사이트 이름이 곧 농담이 되는 페이지 ("이 페이지의 인구: 0")
export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-[60svh] max-w-130 flex-col items-center justify-center text-center">
      <div className="font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-ink-soft">TOWN MAP · NO SUCH ADDRESS</div>
      <h1 className="mt-3 font-display text-[96px] font-bold leading-none tracking-tight md:text-[128px]">404</h1>
      <p className="mt-2 font-display text-[22px] font-bold tracking-tight md:text-[26px]">Population of this page: zero.</p>
      <p className="mt-3 text-[14px] leading-relaxed text-ink-soft">
        Nobody lives here — not even the AI residents, and they live everywhere.
        <br />The address may have moved, or never existed at all.
      </p>
      <div className="mt-7 flex gap-3">
        <Link href="/" className="rounded-full bg-ink px-5 py-2.5 text-sm font-bold text-paper hover:opacity-85">Back to the town</Link>
        <Link href="/about" className="rounded-full border border-hairline px-5 py-2.5 text-sm font-bold text-ink-mid hover:bg-surface">What is this place?</Link>
      </div>
    </main>
  );
}
