import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { timeAgo, postHref, excerpt } from '@/lib/content';
import { SectionLabel } from '@/components/ui';
import { SaveButton } from '@/components/SaveButton';

interface SavedPost { id: number; title: string; body: string; handle: string; created_at: string; saved_at: string }
interface SavedTrend { id: number; title: string; url: string | null; source_name: string | null; image: string | null; saved_at: string }

/** 나중에 읽기 — 저장해 둔 글과 뉴스. 계정이 있어야 하는 기능이고, 계정이 있을 이유 중 하나다. */
export async function SavedPage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const db = await getDb();
  const [{ results: posts }, { results: news }] = await db.batch([
    db.prepare(`SELECT p.id, p.title, substr(p.body, 1, 300) AS body, COALESCE(r.handle, u.handle, 'unknown') AS handle,
        p.created_at, s.created_at AS saved_at
      FROM saves s JOIN posts p ON p.id = s.ref_id
      LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
      WHERE s.user_id = ? AND s.kind = 'post' AND p.hidden = 0 ORDER BY s.created_at DESC LIMIT 60`).bind(user.id),
    db.prepare(`SELECT t.id, t.title, t.url, t.source_name, t.image, s.created_at AS saved_at
      FROM saves s JOIN trends t ON t.id = s.ref_id
      WHERE s.user_id = ? AND s.kind = 'trend' ORDER BY s.created_at DESC LIMIT 60`).bind(user.id),
  ]);
  const savedPosts = posts as unknown as SavedPost[];
  const savedNews = news as unknown as SavedTrend[];

  return (
    <main className="mx-auto mt-10 max-w-3xl">
      <h1 className="font-display text-[30px] font-bold tracking-tight">Bookmarks</h1>
      <p className="mt-2 text-[13.5px] text-ink-soft">Things you kept for later. Nobody else sees this page.</p>

      {!savedPosts.length && !savedNews.length && (
        <p className="py-14 text-[13.5px] text-ink-soft">
          No bookmarks yet. Use the bookmark on a post or a news card and it lands here.
        </p>
      )}

      {savedPosts.length > 0 && (
        <>
          <SectionLabel>POSTS · {savedPosts.length}</SectionLabel>
          <ul className="grid gap-3">
            {savedPosts.map((p) => (
              <li key={p.id} className="flex items-start gap-3 rounded-xl bg-paper p-4 shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
                <div className="min-w-0 flex-1">
                  <Link href={postHref(p.id, p.title)} className="text-[15px] font-bold hover:underline">{p.title}</Link>
                  <p className="mt-1 line-clamp-2 text-[13px] text-ink-mid">{excerpt(p.body)}</p>
                  <p className="mt-1 text-[12px] text-ink-soft">{p.handle} · posted {timeAgo(p.created_at)} · bookmarked {timeAgo(p.saved_at)}</p>
                </div>
                <SaveButton kind="post" id={p.id} initial />
              </li>
            ))}
          </ul>
        </>
      )}

      {savedNews.length > 0 && (
        <>
          <SectionLabel>NEWS · {savedNews.length}</SectionLabel>
          <ul className="grid gap-3">
            {savedNews.map((t) => (
              <li key={t.id} className="flex items-start gap-3 rounded-xl bg-paper p-4 shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
                {t.image && <img src={t.image} alt="" referrerPolicy="no-referrer" className="size-16 shrink-0 rounded-lg object-cover" />}
                <div className="min-w-0 flex-1">
                  {t.url
                    ? <a href={t.url} target="_blank" rel="noopener noreferrer" className="text-[15px] font-bold hover:underline">{t.title}</a>
                    : <span className="text-[15px] font-bold">{t.title}</span>}
                  <p className="mt-1 text-[12px] text-ink-soft">{t.source_name ?? 'Source'} · bookmarked {timeAgo(t.saved_at)}</p>
                </div>
                <SaveButton kind="trend" id={t.id} initial />
              </li>
            ))}
          </ul>
        </>
      )}
    </main>
  );
}
