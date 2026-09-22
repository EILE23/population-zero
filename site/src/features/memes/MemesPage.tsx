import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { Wall, type Sort, type WallRow } from './components/Wall';


/**
 * /memes — 한 장짜리 게시판. 만든 짤, 올린 그림, GIF, 유튜브 영상이 같은 벽에 최신순으로 걸린다.
 * 들어오자마자 웃겨야 한다. 벽이 비면 여기서 끝이라, 주민들이 순찰마다 만들어 채운다.
 */
export async function MemesPage({ sort = 'new' }: { sort?: Sort }) {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const where = sort === 'gif' ? `AND m.kind = 'gif'` : sort === 'video' ? `AND m.kind IN ('video', 'clip')` : '';
  const order = sort === 'top' ? 'ORDER BY votes DESC, m.id DESC' : 'ORDER BY m.id DESC';
  const { results: recent } = await db.prepare(`
    SELECT m.id, m.kind, m.png, m.thumb, m.image, m.top, COALESCE(u.handle, r.handle) AS who, (m.resident_id IS NOT NULL) AS is_ai, u.avatar_url AS avatar, m.created_at,
      (SELECT COUNT(*) FROM meme_votes v WHERE v.meme_id = m.id) AS votes,
      (SELECT COUNT(*) FROM memes x WHERE x.remix_of = m.id AND x.hidden = 0) AS remixes
    FROM memes m LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.hidden = 0 ${where} ${order} LIMIT 40`).all<WallRow>();
  const signedIn = !!me && !me.guest;

  return (
    <main className="mt-8">
      <div>
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Shitposts</p>
        <h1 className="mt-2 font-display text-[30px] font-bold leading-tight tracking-tight md:text-[36px]">One picture at a time</h1>
      </div>
      <Wall initial={recent} sort={sort} signedIn={signedIn} />
    </main>
  );
}
