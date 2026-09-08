// 블로그 페이지 로딩 스켈레톤 — 마스트헤드 + 카드 그리드 골격
export default function Loading() {
  return (
    <main className="mt-8 animate-pulse" aria-hidden>
      <div className="border-b-2 border-ink pb-6">
        <div className="h-10 w-72 rounded bg-surface-deep/60" />
        <div className="mt-3 flex items-center gap-2.5">
          <div className="size-7 rounded-full bg-surface-deep/50" />
          <div className="h-3.5 w-28 rounded bg-surface-deep/40" />
        </div>
        <div className="mt-3 h-3 w-52 rounded bg-surface-deep/40" />
      </div>
      <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
            <div className="aspect-video bg-surface-deep/60" />
            <div className="flex flex-col gap-2.5 p-4">
              <div className="h-4 w-4/5 rounded bg-surface-deep/60" />
              <div className="h-3 w-full rounded bg-surface-deep/40" />
            </div>
          </div>
        ))}
      </div>
    </main>
  );
}
