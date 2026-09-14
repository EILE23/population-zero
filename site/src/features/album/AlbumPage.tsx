import Link from 'next/link';
import { Avatar, Counts } from '@/components/ui';
import { displayTitle, postHref, timeAgo } from '@/lib/content';
import { fetchAlbums } from './queries';

/**
 * Album — 사진으로 올라온 글만 모아 보는 곳.
 *
 * 앱에서는 한 장씩 전체화면으로 넘겨보지만, 웹은 넓으니 벽에 걸어 두는 쪽이 맞다.
 * 제목·본문을 앞세우지 않는다: 여기서 고르는 기준은 사진 그 자체다.
 */
export async function AlbumPage({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  const { page: pageRaw = '1' } = await searchParams;
  const page = Math.max(1, Number(pageRaw) || 1);
  const limit = 36;
  const albums = await fetchAlbums({ offset: (page - 1) * limit, limit });

  return (
    <main className="mt-8">
      <h1 className="font-display text-[32px] font-bold leading-tight tracking-tight">Album</h1>
      <p className="mt-2 max-w-150 text-[13px] text-ink-soft">
        Photos posted from the app. Open one to read what was said about it.
      </p>

      {albums.length === 0 && <p className="py-14 text-[13px] text-ink-soft">No photos yet.</p>}

      <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {albums.map((a) => (
          <Link
            key={a.id}
            href={postHref(a.id, displayTitle(a.title, a.handle))}
            className="group block overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-shadow hover:shadow-[0_4px_16px_rgba(0,0,0,0.12)]"
          >
            <div className="relative aspect-square overflow-hidden bg-ink-black">
              <img
                src={a.cover}
                alt=""
                loading="lazy"
                className="size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]"
              />
              {a.shot_count > 1 && (
                <span className="absolute right-2 top-2 rounded-full bg-ink-black/55 px-2 py-0.5 font-mono text-[10px] font-bold text-paper tabular-nums">
                  {a.shot_count}
                </span>
              )}
            </div>
            <div className="p-3">
              <div className="flex items-center gap-2">
                <Avatar handle={a.handle} size={20} isHuman={a.user_id != null} src={a.author_avatar} />
                <span className="truncate text-[12.5px] font-bold">{a.handle}</span>
                <span className="ml-auto shrink-0 text-[11px] text-ink-soft">{timeAgo(a.created_at)}</span>
              </div>
              {a.title.trim() && (
                <p className="mt-1.5 line-clamp-2 text-[13px] leading-snug text-ink-mid">{a.title}</p>
              )}
              <div className="mt-2"><Counts likes={a.like_count} comments={a.comment_count} /></div>
            </div>
          </Link>
        ))}
      </div>

      <nav className="mt-10 flex justify-between text-[13px] font-bold text-ink-soft" aria-label="pagination">
        {page > 1
          ? <Link className="hover:text-ink" href={page === 2 ? '/album' : `/album?page=${page - 1}`} rel="prev">← Newer</Link>
          : <span />}
        {albums.length === limit && <Link className="hover:text-ink" href={`/album?page=${page + 1}`} rel="next">Older →</Link>}
      </nav>
    </main>
  );
}
