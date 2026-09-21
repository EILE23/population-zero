import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Dices, Paintbrush } from 'lucide-react';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { BUTTON } from '@/components/button-styles';
import { Avatar } from '@/components/ui';
import { memeHref, youtubeEmbed, youtubeId, type MemeKind } from '@/lib/memes';
import { timeAgo } from '@/lib/content';
import { VoteButton } from './components/VoteButton';

interface Row { id: number; kind: MemeKind; image: string; png: string; top: string; who: string; is_ai: number; avatar: string | null; votes: number; remix_of: number | null; created_at: string }

/** /m/<id> — 한 장. 공유하면 이 주소로 사람이 들어온다(OG 이미지 = 그 그림 또는 영상 썸네일) */
export async function MemePage({ id }: { id: number }) {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const m = await db.prepare(`
    SELECT m.id, m.kind, m.image, m.png, m.top, COALESCE(u.handle, r.handle) AS who, (m.resident_id IS NOT NULL) AS is_ai, u.avatar_url AS avatar, m.remix_of, m.created_at,
      (SELECT COUNT(*) FROM meme_votes v WHERE v.meme_id = m.id) AS votes
    FROM memes m LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.id = ? AND m.hidden = 0`).bind(id).first<Row>();
  if (!m) notFound();

  const { results: remixes } = await db.prepare(`
    SELECT m.id, m.png, COALESCE(u.handle, r.handle) AS who FROM memes m
    LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.remix_of = ? AND m.hidden = 0 ORDER BY m.id DESC LIMIT 12`).bind(id).all<{ id: number; png: string; who: string }>();
  const signedIn = !!me && !me.guest;
  const yt = m.kind === 'video' ? youtubeId(m.image) : null;

  return (
    <main className="mx-auto mt-8 max-w-3xl">
      {m.top && m.kind !== 'image' ? <h1 className="mb-3 font-display text-[24px] font-bold leading-tight tracking-tight">{m.top}</h1> : null}
      <div className="overflow-hidden rounded-2xl border border-hairline bg-paper">
        {yt ? (
          <iframe src={youtubeEmbed(yt)} title={m.top || 'video'} className="aspect-video w-full" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowFullScreen />
        ) : m.kind === 'clip' ? (
          <video src={m.image} poster={m.png} controls autoPlay muted loop playsInline className="mx-auto block max-h-[80vh] w-auto" />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={m.png} alt={m.top || ''} className="block w-full" />
        )}
      </div>
      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-[13px] text-ink-soft">
        <Link href={`/@${m.who.toLowerCase().replace(/ /g, '-')}`} className="inline-flex items-center gap-1.5 font-bold text-ink hover:underline">
          <Avatar handle={m.who} size={22} isHuman={!m.is_ai} src={m.avatar} />{m.who}
        </Link>
        <span>{timeAgo(m.created_at)}</span>
        {m.remix_of && <Link href={memeHref(m.remix_of)} className="underline underline-offset-2">remix of #{m.remix_of}</Link>}
        <span className="ml-auto flex items-center gap-2">
          <VoteButton id={m.id} initial={m.votes} signedIn={signedIn} back={memeHref(m.id)} />
          {m.kind !== 'video' && (
            <Link href={`/memes/new?remix=${m.id}`} className={`${BUTTON.primary} inline-flex items-center gap-1.5 !py-1`}><Paintbrush size={13} aria-hidden /> Remix</Link>
          )}
        </span>
      </div>

      {remixes.length > 0 && (
        <section className="mt-8">
          <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Remixes · {remixes.length}</p>
          <ul className="mt-3 grid grid-cols-3 gap-3 sm:grid-cols-4">
            {remixes.map((r) => (
              <li key={r.id}>
                <Link href={memeHref(r.id)} className="block overflow-hidden rounded-lg border border-hairline">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={r.png} alt="" loading="lazy" className="block w-full" />
                </Link>
                <p className="mt-1 truncate text-[11.5px] text-ink-soft">{r.who}</p>
              </li>
            ))}
          </ul>
        </section>
      )}

      <div className="mt-10 flex flex-wrap gap-2 border-t border-hairline pt-6">
        <Link href="/memes/new" className={`${BUTTON.primary} inline-flex items-center gap-1.5`}>Post one</Link>
        <Link href="/memes/new?roll=1" className={`${BUTTON.ghost} inline-flex items-center gap-1.5`}><Dices size={14} aria-hidden /> No context</Link>
        <Link href="/memes" className={BUTTON.ghost}>The wall</Link>
      </div>
    </main>
  );
}
