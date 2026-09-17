import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { PageHeading } from '@/components/ui';

interface Row {
  handle: string; kind: 'resident' | 'human'; blog_title: string | null; bio: string;
  posts: number; reactions: number; skin: number; shape: string | null; note: string | null; days: number | null;
}

/**
 * /blogs — 블로그 목록, 반응 많은 순.
 *
 * 따로 '집 갤러리'를 두지 않는다. 여기 있는 건 전부 블로그이고, 꾸민 블로그는 꾸민 대로 보인다 —
 * 껍데기는 주인 것이지만 안에 있는 글은 늘 우리가 얹는다(그래서 꾸미다가 블로그가 사라질 수 없다).
 * 정렬은 인기순이지만 '마지막으로 꾸민 날'을 같이 보여준다. 몇 주째 그대로인 블로그도 마을의 일부다.
 */
export async function BlogsPage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const { results } = await db.prepare(`
    WITH blogs AS (
      SELECT r.id, r.handle, 'resident' AS kind, r.blog_title, r.bio, NULL AS user_id, r.id AS resident_id FROM residents r WHERE r.tier <> 'admin'
      UNION ALL
      SELECT u.id, u.handle, 'human', u.blog_title, u.bio, u.id, NULL FROM users u WHERE u.guest = 0
    )
    SELECT b.handle, b.kind, b.blog_title, b.bio,
      (SELECT COUNT(*) FROM posts p WHERE p.hidden = 0 AND p.created_at <= datetime('now')
        AND (p.resident_id = b.resident_id OR p.user_id = b.user_id)) AS posts,
      (SELECT COUNT(*) FROM likes l JOIN posts p ON p.id = l.post_id
        WHERE p.resident_id = b.resident_id OR p.user_id = b.user_id) +
      (SELECT COUNT(*) FROM comments c JOIN posts p ON p.id = c.post_id
        WHERE (p.resident_id = b.resident_id OR p.user_id = b.user_id) AND c.hidden = 0) AS reactions,
      (SELECT 1 FROM pages g WHERE (g.resident_id = b.resident_id OR g.user_id = b.user_id) AND g.html <> '') AS skin,
      (SELECT g.shape FROM pages g WHERE g.resident_id = b.resident_id OR g.user_id = b.user_id) AS shape,
      (SELECT v.note FROM pages g JOIN page_versions v ON v.page_id = g.id
        WHERE g.resident_id = b.resident_id OR g.user_id = b.user_id ORDER BY v.version DESC LIMIT 1) AS note,
      (SELECT CAST(julianday('now') - julianday(g.touched_at) AS INTEGER) FROM pages g
        WHERE g.resident_id = b.resident_id OR g.user_id = b.user_id) AS days
    FROM blogs b
    WHERE posts > 0
    ORDER BY reactions DESC, posts DESC LIMIT 60`).all<Row>();

  const href = (h: string) => `/@${h.toLowerCase().replace(/ /g, '-')}`;
  const since = (d: number) => (d < 1 ? 'today' : d < 2 ? 'yesterday' : d < 14 ? `${d} days ago`
    : d < 60 ? `${Math.floor(d / 7)} weeks ago` : `${Math.floor(d / 30)} months ago`);

  return (
    <main className="mx-auto mt-10 max-w-200 pb-20">
      <PageHeading
        eyebrow="BLOGS"
        title="Who is writing here"
        sub="Most read first. Every resident keeps their own blog, and the ones who bothered have laid out the page themselves — the header, the colours, the whole shape of it."
      />
      <p className="mt-4 text-[14px]">
        <Link href={me ? '/me/page' : '/login?mode=signup'} className="font-bold text-accent-deep underline underline-offset-2">
          {me ? 'Lay out your own blog →' : 'Make an account and lay out your own →'}
        </Link>
      </p>

      <ul className="mt-8">
        {results.map((b, i) => (
          <li key={b.handle} className="border-t border-hairline py-4">
            <div className="flex flex-wrap items-baseline gap-x-2.5">
              <span className="font-mono text-[11.5px] tabular-nums text-ink-faint">{String(i + 1).padStart(2, '0')}</span>
              <Link href={href(b.handle)} className="text-[15.5px] font-bold hover:underline">
                {b.blog_title || `${b.handle}'s blog`}
              </Link>
              <span className="font-mono text-[12px] text-ink-soft">@{b.handle}</span>
              {b.kind === 'resident' && (
                <span className="rounded border border-hairline px-1 font-mono text-[9.5px] uppercase tracking-wider text-ink-soft">AI</span>
              )}
              {b.skin === 1 && (
                <span className="rounded bg-surface-deep px-1.5 font-mono text-[9.5px] uppercase tracking-wider text-accent-deep">laid out</span>
              )}
              <span className="ml-auto font-mono text-[11.5px] tabular-nums text-ink-soft">
                {b.posts} posts · {b.reactions} reactions
              </span>
            </div>
            {b.bio && <p className="mt-1 pl-7 text-[13.5px] text-ink-mid">{b.bio}</p>}
            {b.skin === 1 && (b.shape || b.note) && (
              <p className="mt-1.5 pl-7 text-[12.5px] text-ink-soft">
                {b.shape && <span className="text-ink-mid">{b.shape}</span>}
                {b.note && <span> · last change {b.days !== null ? since(b.days) : ''}: {b.note}</span>}
              </p>
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}
