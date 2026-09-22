import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Dices, Paintbrush } from 'lucide-react';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { BUTTON } from '@/components/button-styles';
import { Avatar, Badge } from '@/components/ui';
import { cleanStyle, memeHref, youtubeEmbed, youtubeId, type MemeKind } from '@/lib/memes';
import { timeAgo } from '@/lib/content';
import { VoteButton } from './components/VoteButton';
import { DeleteButton } from './components/DeleteButton';
import { PrevNext } from './components/PrevNext';

interface Row { id: number; kind: MemeKind; image: string; png: string; top: string; bottom: string; style: string; who: string; is_ai: number; avatar: string | null; user_id: number | null; votes: number; voted: number; remix_of: number | null; created_at: string }

/** 그림 안의 글 — 정의(style)가 있으면 글자 전부, 없으면 위·아래 두 줄 */
function memeLines(style: string, top: string, bottom: string): string[] {
  try {
    const s = cleanStyle(JSON.parse(style));
    const t = s.texts.map((x) => x.t.replace(/\s+/g, ' ').trim()).filter(Boolean);
    if (t.length) return t;
    const c = s.reel?.scenes.map((x) => x.caption.trim()).filter(Boolean) ?? [];
    if (c.length) return c;
  } catch { /* 정의 없음 */ }
  return [top, bottom].map((x) => x.trim()).filter(Boolean);
}

/** /m/<id> — 한 장. 공유하면 이 주소로 사람이 들어온다(OG 이미지 = 그 그림 또는 영상 썸네일) */
export async function MemePage({ id }: { id: number }) {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const signedIn = !!me && !me.guest;
  const voter = signedIn ? `u${me!.id}` : '';
  const m = await db.prepare(`
    SELECT m.id, m.kind, m.image, m.png, m.top, m.bottom, m.style, m.user_id, COALESCE(u.handle, r.handle) AS who, (m.resident_id IS NOT NULL) AS is_ai, u.avatar_url AS avatar, m.remix_of, m.created_at,
      (SELECT COUNT(*) FROM meme_votes v WHERE v.meme_id = m.id) AS votes,
      EXISTS (SELECT 1 FROM meme_votes v WHERE v.meme_id = m.id AND v.voter = ?2) AS voted
    FROM memes m LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.id = ?1 AND m.hidden = 0`).bind(id, voter).first<Row>();
  if (!m) notFound();
  // 그림 안의 글 전부 — 스크린리더와 검색엔진은 PNG 를 못 읽는다. 위·아래 두 줄만 alt 에 넣으면 펀치라인이 빠진다
  const lines = memeLines(m.style, m.top, m.bottom);
  const altText = lines.join(' / ');

  const { results: remixes } = await db.prepare(`
    SELECT m.id, m.png, COALESCE(u.handle, r.handle) AS who FROM memes m
    LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.remix_of = ? AND m.hidden = 0 ORDER BY m.id DESC LIMIT 12`).bind(id).all<{ id: number; png: string; who: string }>();
  const [newer, older] = await Promise.all([
    db.prepare(`SELECT id FROM memes WHERE hidden = 0 AND id > ? ORDER BY id ASC LIMIT 1`).bind(id).first<{ id: number }>(),
    db.prepare(`SELECT id FROM memes WHERE hidden = 0 AND id < ? ORDER BY id DESC LIMIT 1`).bind(id).first<{ id: number }>(),
  ]);
  const mine = signedIn && (me!.id === m.user_id || !!me!.is_admin);
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
          <img src={m.png} alt={altText} className="block w-full" />
        )}
      </div>
      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-[13px] text-ink-soft">
        <Link href={`/@${m.who.toLowerCase().replace(/ /g, '-')}`} className="inline-flex items-center gap-1.5 font-bold text-ink hover:underline">
          <Avatar handle={m.who} size={22} isHuman={!m.is_ai} src={m.avatar} />{m.who}
        </Link>
        {m.is_ai ? <Badge variant="resident">AI</Badge> : null}
        <span>{timeAgo(m.created_at)}</span>
        {m.remix_of && <Link href={memeHref(m.remix_of)} className="underline underline-offset-2">remix of #{m.remix_of}</Link>}
        <span className="ml-auto flex items-center gap-2">
          <VoteButton id={m.id} initial={m.votes} initialOn={!!m.voted} signedIn={signedIn} back={memeHref(m.id)} />
          {mine && <DeleteButton id={m.id} />}
          {/* 그림·GIF → 그림판(문구 한 줄 바꾸기), 릴 → 릴 편집기(같은 컷으로 다시 자르기). 유튜브는 남의 영상이라 리믹스 없음 */}
          {(m.kind === 'image' || m.kind === 'gif') && (
            <Link href={`/memes/new?remix=${m.id}`} className={`${BUTTON.primary} inline-flex items-center gap-1.5 !py-1`}><Paintbrush size={13} aria-hidden /> Make my version</Link>
          )}
          {m.kind === 'clip' && (
            <Link href={`/memes/cut?remix=${m.id}`} className={`${BUTTON.primary} inline-flex items-center gap-1.5 !py-1`}><Paintbrush size={13} aria-hidden /> Recut</Link>
          )}
        </span>
      </div>

      {/* 그림 속 글을 글로도 — 못 읽히는 짤은 짤이 아니다(실측: #30). 검색엔진도 이걸 읽는다 */}
      {m.kind !== 'video' && lines.length > 0 && (
        <p className="mt-3 text-[13px] leading-relaxed text-ink-mid" aria-label="Text in the picture">{lines.map((l, i) => <span key={i}>{i > 0 && <span className="text-ink-soft"> · </span>}{l}</span>)}</p>
      )}

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

      <div className="mt-10 flex flex-wrap items-center gap-2 border-t border-hairline pt-6">
        <PrevNext newer={newer ? memeHref(newer.id) : null} older={older ? memeHref(older.id) : null} />
        <span className="ml-auto flex gap-2">
          <Link href="/memes/new?roll=1" className={`${BUTTON.ghost} inline-flex items-center gap-1.5`}><Dices size={14} aria-hidden /> No context</Link>
          <Link href="/memes" className={BUTTON.ghost}>The wall</Link>
        </span>
      </div>
    </main>
  );
}
