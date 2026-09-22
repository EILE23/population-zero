import Link from 'next/link';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { GOOGLE_FONTS_HREF } from '@/lib/meme-draw';
import { cleanStyle, memeHref, type MemeReel } from '@/lib/memes';
import { ReelEditor } from './components/ReelEditor';

/** /memes/cut — 옛 필름을 잘라 세로 영상을 만든다. 주민이 쓰는 재료·글꼴과 같다. ?remix=<id> 면 그 릴의 구성으로 시작 */
export async function ReelCutPage({ searchParams }: { searchParams?: Promise<{ remix?: string }> } = {}) {
  const { remix } = (await searchParams) ?? {};
  const me = await getSessionUser();
  let initial: (MemeReel & { remixOf: number }) | undefined;
  if (remix && /^\d+$/.test(remix)) {
    const db = await getDb();
    const src = await db.prepare(`SELECT id, style FROM memes WHERE id = ? AND hidden = 0 AND kind = 'clip'`).bind(Number(remix)).first<{ id: number; style: string }>();
    if (src) {
      let reel: MemeReel | undefined;
      try { reel = cleanStyle(JSON.parse(src.style)).reel; } catch { /* 정의 없음 */ }
      if (reel) initial = { ...reel, remixOf: src.id };
    }
  }
  return (
    <main className="mt-6">
      <link rel="stylesheet" href={GOOGLE_FONTS_HREF} />
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <div>
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">
            {initial ? <>Remix of <Link className="underline" href={memeHref(initial.remixOf)}>#{initial.remixOf}</Link></> : 'Shitposts'}
          </p>
          <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">{initial ? 'Recut this reel' : 'Cut a reel'}</h1>
          <p className="mt-1 text-[13.5px] text-ink-mid">Public-domain films, cut into shots. Pick shots, put dumb words on them, record. Vertical, with the original sound.</p>
        </div>
        <span className="flex gap-3 text-[13px] font-semibold text-ink-mid">
          <Link href="/memes/new" className="underline underline-offset-2">pictures instead</Link>
          <Link href="/memes" className="underline underline-offset-2">← the wall</Link>
        </span>
      </div>
      <ReelEditor signedIn={!!me && !me.guest} initial={initial} />
    </main>
  );
}
