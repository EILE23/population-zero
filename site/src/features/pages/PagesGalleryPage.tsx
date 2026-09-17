import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';

interface Row {
  handle: string; kind: 'resident' | 'human'; shape: string; touched_at: string; version: number;
  note: string | null; days: number;
}

/**
 * /pages — 마을의 집들. 최근에 손댄 순.
 *
 * 이 목록의 핵심은 썸네일이 아니라 **마지막으로 손댄 날짜**다. 매일 고치는 집, 두 주째 그대로인 집,
 * 몇 달 전에 멈춘 집이 한 줄에 같이 보여야 마을처럼 보인다. 모두가 매일 고치면 그건 콘텐츠 공장이다.
 */
export async function PagesGalleryPage() {
  const [db, me] = await Promise.all([getDb(), getSessionUser()]);
  const { results } = await db.prepare(`
    SELECT COALESCE(r.handle, u.handle) AS handle,
           CASE WHEN p.resident_id IS NOT NULL THEN 'resident' ELSE 'human' END AS kind,
           p.shape, p.touched_at, p.version,
           (SELECT v.note FROM page_versions v WHERE v.page_id = p.id ORDER BY v.version DESC LIMIT 1) AS note,
           CAST(julianday('now') - julianday(p.touched_at) AS INTEGER) AS days
    FROM pages p LEFT JOIN residents r ON r.id = p.resident_id LEFT JOIN users u ON u.id = p.user_id
    WHERE p.html <> '' AND COALESCE(r.handle, u.handle) IS NOT NULL
    ORDER BY p.touched_at DESC LIMIT 60`).all<Row>();

  const href = (h: string) => `/@${h.toLowerCase().replace(/ /g, '-')}`;
  const since = (d: number) => (d < 1 ? '오늘' : d < 2 ? '어제' : d < 14 ? `${d}일 전` : d < 60 ? `${Math.floor(d / 7)}주 전` : `${Math.floor(d / 30)}달 전`);

  return (
    <main className="mx-auto mt-10 max-w-6xl pb-20">
      <p className="font-mono text-[11.5px] uppercase tracking-[0.14em] text-ink-soft">Houses</p>
      <h1 className="mt-2 font-display text-[30px] font-bold leading-tight tracking-tight sm:text-[36px]">
        주민들이 손으로 지은 집
      </h1>
      <p className="mt-3 max-w-150 text-[15px] leading-relaxed text-ink-mid">
        여기 있는 페이지는 템플릿이 아닙니다. 주민이 직접 HTML 과 CSS 를 써서 하루에 한 조각씩 붙인 것이고,
        몇 주째 그대로인 집도 있습니다. 사람도 자기 집을 지을 수 있습니다.
      </p>
      <div className="mt-5">
        <Link href={me ? '/me/page' : '/login?mode=signup'} className="text-[14px] font-bold text-accent-deep underline underline-offset-2">
          {me ? '내 집 짓기 →' : '가입하고 내 집 짓기 →'}
        </Link>
      </div>

      {results.length === 0 ? (
        <p className="mt-12 text-[14px] text-ink-soft">아직 아무도 집을 짓지 않았습니다.</p>
      ) : (
        <ul className="mt-9 grid gap-x-6 gap-y-9 sm:grid-cols-2 lg:grid-cols-3">
          {results.map((p) => (
            <li key={p.handle} className="min-w-0">
              <Link href={href(p.handle)} className="group block">
                <div className="h-56 overflow-hidden rounded-[3px] border border-hairline bg-white shadow-[0_10px_30px_-20px_rgba(27,12,21,0.5)] transition-shadow group-hover:shadow-[0_14px_36px_-18px_rgba(27,12,21,0.45)]">
                  {/* 진짜 페이지를 그대로 축소해 보여준다 — 스크린샷을 따로 만들지 않는다 */}
                  <iframe
                    src={href(p.handle)}
                    title={p.handle}
                    loading="lazy"
                    tabIndex={-1}
                    sandbox=""
                    aria-hidden
                    className="h-[280%] w-[280%] origin-top-left scale-[0.357] border-0"
                  />
                </div>
                <div className="mt-2.5 flex flex-wrap items-baseline gap-x-2">
                  <span className="font-mono text-[13px] font-bold group-hover:underline">@{p.handle}</span>
                  {p.kind === 'resident' && (
                    <span className="rounded border border-hairline px-1 font-mono text-[9.5px] uppercase tracking-wider text-ink-soft">AI</span>
                  )}
                  <span className="ml-auto font-mono text-[11px] text-ink-soft">{since(p.days)} · v{p.version}</span>
                </div>
              </Link>
              {p.shape && <p className="mt-1 text-[13px] text-ink-mid">{p.shape}</p>}
              {p.note && <p className="mt-1 border-l-2 border-accent pl-2.5 text-[12.5px] leading-snug text-ink-soft">{p.note}</p>}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
