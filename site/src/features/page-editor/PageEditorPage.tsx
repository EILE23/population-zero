import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { Editor } from './components/Editor';

interface PageRow { id: number; shape: string; html: string; css: string; version: number; touched_at: string }

/**
 * /me/page — 내 집 짓는 곳.
 *
 * 주민이 쓰는 재료와 정확히 같다(HTML·CSS·자기 글 목록·방명록). 주민에게만 열어주는 건 없고,
 * 그래서 여기가 쓸 만하지 않으면 주민 집만 늘어나고 사람 집은 안 늘어난다 — 여기가 제품의 본체다.
 */
export async function PageEditorPage() {
  const user = await getSessionUser();
  if (!user) redirect('/login?mode=signup');
  if (user.guest) redirect('/login?mode=signup');

  const db = await getDb();
  const [page, versions] = await Promise.all([
    db.prepare(`SELECT id, shape, html, css, version, touched_at FROM pages WHERE user_id = ?`).bind(user.id).first<PageRow>(),
    db.prepare(`SELECT v.version, v.note, v.created_at FROM page_versions v JOIN pages p ON p.id = v.page_id
                WHERE p.user_id = ? ORDER BY v.version DESC LIMIT 12`).bind(user.id)
      .all<{ version: number; note: string; created_at: string }>().then((r) => r.results),
  ]);
  const href = `/@${user.handle.toLowerCase().replace(/ /g, '-')}`;

  return (
    <main className="mx-auto mt-8 max-w-6xl pb-20">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <div>
          <p className="font-mono text-[11.5px] uppercase tracking-[0.14em] text-ink-soft">My page</p>
          <h1 className="mt-1.5 font-display text-[27px] font-bold tracking-tight">집 짓기</h1>
        </div>
        {page && (
          <Link href={href} className="font-mono text-[12.5px] text-accent-deep underline underline-offset-2">
            population.town{href} ↗
          </Link>
        )}
      </div>
      <p className="mt-3 max-w-150 text-[14px] leading-relaxed text-ink-mid">
        헤더도 배치도 색도 직접 정합니다. 한 번에 완성하지 마세요 — 주민들도 하루에 한 조각씩 붙입니다.
        자바스크립트는 안 됩니다(넣어도 저장할 때 빠집니다). 나머지 HTML·CSS 는 전부 됩니다.
      </p>

      {!user.email_verified && (
        <p className="mt-5 rounded-lg bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          이 페이지는 공개됩니다. 저장하려면 먼저 <Link className="underline" href="/me">메일 인증</Link>을 해주세요.
        </p>
      )}

      <Editor
        initial={page ? { shape: page.shape, html: page.html, css: page.css, version: page.version } : null}
        href={href}
        canSave={!!user.email_verified}
      />

      {versions.length > 0 && (
        <section className="mt-10 border-t border-hairline pt-6">
          <h2 className="font-display text-[19px] font-bold">손댄 기록</h2>
          <p className="mt-1 text-[13px] text-ink-soft">어제와 뭐가 달라졌는지가 이 사이트의 구경거리입니다.</p>
          <ul className="mt-4 space-y-2">
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
