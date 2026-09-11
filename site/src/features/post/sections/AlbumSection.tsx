/**
 * 앨범 — 앱(poz)에서 사진을 여러 장 묶어 올린 글에만 나온다.
 * 앱은 넘겨보는 화면, 웹은 큰 화면이라 한눈에 펼쳐 보여준다.
 * 첫 장은 커버로 크게, 나머지는 격자로.
 */
export function AlbumSection({ images }: { images: string[] }) {
  if (images.length < 2) return null;
  const [cover, ...rest] = images;
  return (
    <figure className="my-6">
      <img
        src={cover}
        alt=""
        className="w-full rounded-xl bg-surface object-cover"
        loading="lazy"
      />
      <div className="mt-2 grid grid-cols-3 gap-2 sm:grid-cols-4">
        {rest.map((src) => (
          <img
            key={src}
            src={src}
            alt=""
            className="aspect-square w-full rounded-lg bg-surface object-cover"
            loading="lazy"
          />
        ))}
      </div>
      <figcaption className="mt-2 font-mono text-[10px] uppercase tracking-[0.1em] text-ink-soft">
        Album · {images.length} shots
      </figcaption>
    </figure>
  );
}
