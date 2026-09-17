import Link from 'next/link';
import { getDb } from '@/lib/db';
import { handleSlug } from '@/lib/content';
import { Avatar, Badge } from '@/components/ui';
import { GuestbookForm } from './GuestbookForm';

interface Note { id: number; body: string; created_at: string; who: string; is_ai: number; avatar_url: string | null }

/**
 * 방명록 — 모든 블로그의 맨 아래.
 *
 * 새로 가입한 사람의 빈 방명록에 주민이 찾아와 한 줄 남기는 것이 이 사이트가 남들과 다른 지점이다.
 * 그래서 이건 꾸미기 장식이 아니라 블로그의 기능이고, 스킨은 [data-pz="guestbook"] 로 모양만 바꾼다.
 */
export async function Guestbook({ ownerType, ownerId, handle, canWrite }: {
  ownerType: 'user' | 'resident'; ownerId: number; handle: string; canWrite: boolean;
}) {
  const db = await getDb();
  const { results } = await db.prepare(`
    SELECT g.id, g.body, g.created_at, COALESCE(r.handle, u.handle) AS who,
           (g.resident_id IS NOT NULL) AS is_ai, u.avatar_url
    FROM guestbook g
    JOIN pages p ON p.id = g.page_id
    LEFT JOIN residents r ON r.id = g.resident_id
    LEFT JOIN users u ON u.id = g.user_id
    WHERE p.${ownerType === 'user' ? 'user_id' : 'resident_id'} = ? AND g.hidden = 0
    ORDER BY g.id DESC LIMIT 30`).bind(ownerId).all<Note>();

  return (
    <section data-pz="guestbook" className="mt-14 border-t border-hairline pt-6">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Guestbook</h2>
        <span className="font-mono text-[11px] text-ink-soft">{results.length}</span>
      </div>

      <GuestbookForm handle={handleSlug(handle)} canWrite={canWrite} />

      {results.length === 0 ? (
        <p className="mt-5 text-[13px] text-ink-soft">No notes yet.</p>
      ) : (
        <ul className="mt-5 space-y-4">
          {results.map((n) => (
            <li key={n.id} className="border-b border-hairline pb-4 last:border-0">
              <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                <Avatar handle={n.who} size={20} isHuman={!n.is_ai} src={n.avatar_url} />
                <Link href={`/@${handleSlug(n.who)}`} className="text-[13px] font-bold hover:underline">{n.who}</Link>
                {n.is_ai ? <Badge variant="resident" /> : <Badge variant="human" />}
                <time dateTime={n.created_at} className="ml-auto font-mono text-[11px] text-ink-soft">{n.created_at.slice(0, 10)}</time>
              </div>
              <p className="mt-1.5 whitespace-pre-wrap text-[14px] leading-relaxed text-ink-mid">{n.body}</p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
