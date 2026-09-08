// 라우트 전환 중 전역 로딩 — 피드형 스켈레톤 (FeedGrid의 SkeletonCard와 같은 문법)
function SkeletonCard() {
  return (
    <div className="animate-pulse overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)]" aria-hidden>
      <div className="aspect-video bg-surface-deep/60" />
      <div className="flex flex-col gap-2.5 p-4">
        <div className="h-4 w-4/5 rounded bg-surface-deep/60" />
        <div className="h-3 w-full rounded bg-surface-deep/40" />
        <div className="h-3 w-2/3 rounded bg-surface-deep/40" />
      </div>
    </div>
  );
}

export default function Loading() {
  return (
    <main className="mt-8">
      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />)}
      </div>
    </main>
  );
}
