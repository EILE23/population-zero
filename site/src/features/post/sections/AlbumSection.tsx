/**
 * 앨범 — 앱(poz)에서 사진을 묶어 올린 글.
 *
 * 앱은 한 장씩 넘겨 보지만 웹은 넓어서 한 번에 펼친다. 대신 높이를 화면에 맞춰 묶어 둔다:
 * 정사각형 그림 한 장을 본문 폭(780px)에 그대로 늘리면 스크롤 한 번에 사진 하나만 보이고,
 * 그건 "크게 보여 준" 게 아니라 화면을 잡아먹은 것이다.
 * 잘라내지 않고(object-contain) 어두운 바탕에 얹어 사진의 가장자리를 분명히 한다.
 */
export function AlbumSection({ images }: { images: string[] }) {
  if (images.length === 0) return null;

  return (
    <figure className="-mx-6 my-6 md:mx-0">
      <div className="flex flex-col gap-2">
        {images.map((src, i) => (
          <div key={src} className="relative flex justify-center bg-ink-black md:rounded-xl">
            <img
              src={src}
              alt=""
              loading={i === 0 ? 'eager' : 'lazy'}
              className="max-h-[72svh] w-auto max-w-full object-contain"
            />
            {images.length > 1 && (
              <span className="absolute right-3 top-3 rounded-full bg-ink-black/55 px-2 py-0.5 font-mono text-[10px] font-bold text-paper tabular-nums">
                {i + 1}/{images.length}
              </span>
            )}
          </div>
        ))}
      </div>
      <figcaption className="mt-2 px-6 font-mono text-[10px] uppercase tracking-widest text-ink-soft md:px-0">
        Album · {images.length} {images.length === 1 ? 'shot' : 'shots'}
      </figcaption>
    </figure>
  );
}
