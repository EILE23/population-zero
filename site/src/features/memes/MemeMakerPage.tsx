import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { ASSET_PREFIX, cleanStyle, memeHref } from '@/lib/memes';
import { GOOGLE_FONTS_HREF } from '@/lib/meme-draw';
import { MemeMaker } from './components/MemeMaker';
import { MemeUpload } from './components/MemeUpload';

/**
 * /memes/new — 올리기(그림·GIF·유튜브) + 만들기(그림판). ?remix=<id> 면 그 짤 위에서, ?roll=1 이면 🎲 부터 시작한다.
 * 글꼴은 여기서만 받는다(Anton·Comic Neue·Permanent Marker·Tinos) — 짤 글씨는 굵어야 짤이다.
 */
export async function MemeMakerPage({ searchParams }: { searchParams: Promise<{ remix?: string; roll?: string }> }) {
  const { remix, roll } = await searchParams;
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);

  const [{ results: hot }, { results: art }, { results: covers }, source] = await Promise.all([
    // 시작 그림 — 지금 뜨거운 템플릿 30장 중 4장, 명화 2장, 주민 커버 2장
    db.prepare(`SELECT url FROM (SELECT url FROM meme_pool WHERE source = 'imgflip' ORDER BY rank LIMIT 30) ORDER BY RANDOM() LIMIT 4`).all<{ url: string }>(),
    db.prepare(`SELECT url FROM meme_pool WHERE source <> 'imgflip' ORDER BY RANDOM() LIMIT 2`).all<{ url: string }>(),
    // LIKE 는 패턴 50바이트 상한이 있어(SQLITE_ERROR 'pattern too complex') 접두사는 substr 로 비교한다
    db.prepare(`SELECT og_image AS url FROM posts WHERE hidden = 0 AND substr(og_image, 1, ?1) = ?2 ORDER BY RANDOM() LIMIT 2`)
      .bind(ASSET_PREFIX.length, ASSET_PREFIX).all<{ url: string }>(),
    remix && /^\d+$/.test(remix)
      ? db.prepare(`SELECT id, image, png, style FROM memes WHERE id = ? AND hidden = 0 AND kind <> 'video'`).bind(Number(remix)).first<{ id: number; image: string; png: string; style: string }>()
      : Promise.resolve(null),
  ]);
  const pics = [...hot, ...art, ...covers].map((p) => p.url);
  const signedIn = !!me && !me.guest;

  // 리믹스는 원본의 정의(바탕 컷 + 글자)로 시작한다 — 글자 하나하나가 그대로 잡히고 고쳐진다.
  // 정의가 없는 것(그냥 올린 그림)은 그 그림 위에서 시작한다. 붓질층은 저장하지 않으므로 이어받지 못한다.
  let initial: { image: string; style: { texts: import('@/lib/memes').MemeText[]; panels: (string | null)[] }; remixOf: number } | undefined;
  if (source) {
    let style = cleanStyle(null);
    try { style = cleanStyle(JSON.parse(source.style)); } catch { /* 빈 정의 */ }
    const panels = style.panels.some(Boolean) ? style.panels : [source.image || source.png];
    initial = { image: panels[0] ?? source.png, style: { texts: style.texts, panels }, remixOf: source.id };
  }

  return (
    <main className="mt-6">
      {/* 짤 글꼴 — 사이트 본문 글꼴과 별개라 이 화면에서만 받는다 */}
      <link rel="stylesheet" href={GOOGLE_FONTS_HREF} />
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <div>
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">
            {source ? <>Remix of <Link className="underline" href={memeHref(source.id)}>#{source.id}</Link></> : 'Shitposts'}
          </p>
          <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">
            {source ? 'Draw over it' : 'Post one, or draw badly and write worse'}
          </h1>
        </div>
        <Link href="/memes" className="text-[13px] font-semibold text-ink-mid underline underline-offset-2">← the wall</Link>
      </div>
      {!source && <div className="mt-5"><MemeUpload signedIn={signedIn} /></div>}
      {!source && <p className="mt-6 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Or make one</p>}
      <MemeMaker initial={initial} pics={pics} signedIn={signedIn} autoRoll={roll === '1' && !source} />
    </main>
  );
}
