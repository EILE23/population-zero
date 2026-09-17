import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { handleSlug } from '@/lib/content';
import { parseLayout } from '@/lib/blog-layout';
import { fetchProfile } from '@/features/blog/queries';
import { EditorShell } from './components/EditorShell';

/**
 * /me/page — 내 블로그를 마우스로 꾸미는 곳.
 *
 * 저장되는 건 CSS 가 아니라 '블록 순서 + 고른 값'(lib/blog-layout.ts)이다. 그래서 코드를 모르는 사람도
 * 꾸밀 수 있고, 주민도 같은 값을 쓴다(주민에게만 열어주는 건 없다는 규칙).
 * 앱은 같은 값을 읽어 자기 방식으로 그릴 수 있다 — CSS 로 저장하면 앱이 따라올 수 없었다.
 */
export async function PageEditorPage() {
  const user = await getSessionUser();
  if (!user || user.guest) redirect('/login?mode=signup');

  const slug = handleSlug(user.handle);
  const db = await getDb();
  const [row, profile, versions] = await Promise.all([
    db.prepare(`SELECT layout, version, touched_at FROM pages WHERE user_id = ?`).bind(user.id)
      .first<{ layout: string | null; version: number; touched_at: string }>(),
    fetchProfile(slug, user, {}),
    db.prepare(`SELECT v.version, v.note, v.created_at FROM page_versions v JOIN pages p ON p.id = v.page_id
                WHERE p.user_id = ? ORDER BY v.version DESC LIMIT 10`).bind(user.id)
      .all<{ version: number; note: string; created_at: string }>().then((r) => r.results),
  ]);
  if (!profile) redirect('/me');

  const base = `/@${slug}`;
  return (
    <main className="mx-auto mt-8 max-w-7xl pb-20">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <div>
          <p className="font-mono text-[11.5px] uppercase tracking-[0.14em] text-ink-soft">My blog</p>
          <h1 className="mt-1.5 font-display text-[27px] font-bold tracking-tight">Arrange your blog</h1>
        </div>
        <Link href={base} className="font-mono text-[12.5px] text-accent-deep underline underline-offset-2">
          population.town{base} ↗
        </Link>
      </div>
      <p className="mt-3 max-w-150 text-[14px] leading-relaxed text-ink-mid">
        Drag the blocks where you want them and pick how the posts look. Everything your blog does stays —
        you are moving it around, not replacing it. No code anywhere.
      </p>

      {!user.email_verified && (
        <p className="mt-5 rounded-lg bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          Your blog is public, so <Link className="underline" href="/me">verify your email</Link> before saving.
        </p>
      )}

      <EditorShell
        initial={parseLayout(row?.layout)}
        data={{
          owner: profile.owner, posts: profile.posts, topics: profile.topics, pinnedPost: profile.pinnedPost,
          seriesList: profile.seriesList, followerCount: profile.followerCount, followingCount: profile.followingCount,
          isMe: true,
        }}
        base={base}
        canSave={!!user.email_verified}
      />

      {versions.length > 0 && (
        <section className="mt-10 border-t border-hairline pt-6">
          <h2 className="font-display text-[19px] font-bold">What you changed</h2>
          <ul className="mt-3 space-y-2">
            {versions.map((v) => (
              <li key={v.version} className="flex flex-wrap items-baseline gap-x-3 text-[13.5px]">
                <span className="font-mono text-[11.5px] text-ink-soft">v{v.version}</span>
                <span className="font-mono text-[11.5px] text-ink-soft">{v.created_at.slice(0, 10)}</span>
                <span className="text-ink-mid">{v.note}</span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </main>
  );
}
