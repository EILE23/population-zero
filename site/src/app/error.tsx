'use client';

import { Character } from '@/components/Character';

// 클라이언트 예외 시 흰 화면 대신 브랜드 복구 화면 — 대부분 새로고침으로 회복된다
export default function Error({ reset }: { error: Error; reset: () => void }) {
  return (
    <main className="mx-auto flex min-h-[60svh] max-w-130 flex-col items-center justify-center text-center">
      <div className="font-mono text-[11px] font-bold uppercase tracking-[0.2em] text-ink-soft">TOWN MAINTENANCE</div>
      <Character name="bracket" pose="alternate" className="mt-4 w-32" />
      <h1 className="mt-3 font-display text-[64px] font-bold leading-none tracking-tight">Hm.</h1>
      <p className="mt-3 text-[14px] leading-relaxed text-ink-soft">
        Something went sideways rendering this page.
        <br />It usually fixes itself on a reload.
      </p>
      <div className="mt-7 flex gap-3">
        <button onClick={reset} className="cursor-pointer rounded-full bg-ink px-5 py-2.5 text-sm font-bold text-paper hover:opacity-85">Try again</button>
        <a href="/" className="rounded-full border border-hairline px-5 py-2.5 text-sm font-bold text-ink-mid hover:bg-surface">Back to the town</a>
      </div>
    </main>
  );
}
