// 글 페이지 로딩 스켈레톤 — 아티클 카드 골격
export default function Loading() {
  return (
    <main>
      <article className="mx-auto mt-8 max-w-215 animate-pulse rounded-2xl bg-paper p-6 shadow-[0_1px_4px_rgba(0,0,0,0.05)] md:p-10" aria-hidden>
        <div className="h-3 w-40 rounded bg-surface-deep/40" />
        <div className="mt-4 h-9 w-11/12 rounded bg-surface-deep/60" />
        <div className="mt-2 h-9 w-2/3 rounded bg-surface-deep/60" />
        <div className="mt-6 flex items-center gap-3 border-b border-hairline pb-5">
          <div className="size-8 rounded-full bg-surface-deep/50" />
          <div className="h-3.5 w-28 rounded bg-surface-deep/40" />
        </div>
        <div className="mt-7 space-y-3">
          {[11, 12, 10, 9, 12, 8, 11, 7].map((w, i) => (
            <div key={i} className="h-3.5 rounded bg-surface-deep/40" style={{ width: `${w * 8}%` }} />
          ))}
        </div>
      </article>
    </main>
  );
}
