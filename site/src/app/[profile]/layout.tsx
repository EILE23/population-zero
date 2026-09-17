import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { Avatar, Badge } from '@/components/ui';
import { NavActions } from '@/features/layout/NavActions';
import { Footer } from '@/features/layout/Footer';
import { HandlePickerModal } from '@/features/auth/HandlePickerModal';
import { EditableBlogTitle } from '@/features/blog/components/EditableBlogTitle';
import { handleSlug } from '@/lib/content';
import { BrandLogo } from '@/components/BrandLogo';
import { parseLayout, themeVars, DEFAULT_CHROME, type Chrome } from '@/lib/blog-layout';

// 블로그 크롬 — 헤더 좌측 상단이 사이트 로고 대신 "이 블로그"가 된다 (진짜 내 블로그처럼)
export default async function BlogLayout({ children, params }: { children: React.ReactNode; params: Promise<{ profile: string }> }) {
  const { profile } = await params;
  const decoded = decodeURIComponent(profile);
  const slug = decoded.startsWith('@') ? decoded.slice(1) : null;

  let owner: { type: 'user' | 'resident'; id: number; handle: string; blog_title: string | null; tier?: string; avatar_url?: string | null } | null = null;
  let counts = { followers: 0, following: 0 };
  let arranged = false;
  let pageStyle: React.CSSProperties | undefined;
  let pageBg = '';
  let chrome: Chrome = DEFAULT_CHROME;
  let viewer = null;
  if (slug) {
    try {
      const db = await getDb();
      viewer = await getSessionUser();
      owner =
        await db.prepare(`SELECT id, handle, blog_title, avatar_url, 'user' AS type FROM users WHERE handle = ? COLLATE NOCASE`).bind(slug)
          .first<{ id: number; handle: string; blog_title: string | null; avatar_url: string | null; type: 'user' }>()
        ?? await db.prepare(`SELECT id, handle, blog_title, tier, 'resident' AS type FROM residents WHERE lower(replace(handle,' ','-')) = ?`).bind(slug.toLowerCase())
          .first<{ id: number; handle: string; blog_title: string | null; tier: string; type: 'resident' }>();
      if (owner) {
        // 페이지 쪽 fetchProfile 이 같은 카운트를 다시 세지만, 둘 다 읽기라 문제없고 각자 1왕복로 끝난다
        const row = await db.prepare(`SELECT
            (SELECT COUNT(*) FROM follows WHERE target_type = ?1 AND target_id = ?2) AS followers,
            (SELECT COUNT(*) FROM follows WHERE follower_type = ?1 AND follower_id = ?2) AS following`)
          .bind(owner.type, owner.id).first<{ followers: number; following: number }>();
        if (row) counts = row;
        // 배치를 정한 블로그는 제목·주인 줄을 자기 header 블록으로 그린다 — 여기선 얇은 사이트 띠만 남긴다
        const row2 = await db.prepare(
          `SELECT layout FROM pages WHERE ${owner.type === 'user' ? 'user_id' : 'resident_id'} = ? AND layout IS NOT NULL`)
          .bind(owner.id).first<{ layout: string }>();
        arranged = !!row2;
        // 배치가 있으면 고른 색이 페이지 전체를 칠한다 — 캔버스만 칠하면 푸터와 어긋나 보인다
        if (row2) {
          const theme = parseLayout(row2.layout).theme;
          pageStyle = themeVars(theme) as React.CSSProperties;
          pageBg = theme.bg;   // #hex 검증을 통과한 값만 들어온다(cleanLayout)
          chrome = parseLayout(row2.layout).chrome;
        }
      }
    } catch { /* 셸은 항상 렌더 */ }
  }

  const isMe = viewer != null && owner?.type === 'user' && viewer.id === owner.id;
  const base = owner ? `/@${handleSlug(owner.handle)}` : '/';
  const isResident = owner?.type === 'resident';

  return (
    <>
      {/* 브라우저 배경까지 주인이 고른 색으로 — 이 블로그를 볼 때만, 보는 사람이 누구든.
          값은 cleanLayout 의 #hex 검증을 지난 것뿐이라 여기 들어갈 수 있는 건 색밖에 없다. */}
      {pageBg && <style>{`body{background:${pageBg}}`}</style>}
    <div
      id="pz-skin"
      style={pageStyle}
      className={`mx-auto flex min-h-svh flex-col px-5 md:px-8 ${arranged ? 'pz-page max-w-none' : 'max-w-7xl'}`}
    >
      <header data-pz="masthead" className={arranged ? (chrome.nav === 'bottom' ? 'sr-only' : 'py-3') : 'border-b-2 border-ink py-5'}>
        {/* 홈으로 가는 표시 — 주인이 로고·자기 글자·안 보이기 중에 고른다. 안 보이기여도 푸터에 길은 남는다 */}
        {chrome.home !== 'none' && (
          <div className="mb-3 font-mono text-[10.5px] font-bold uppercase tracking-[0.16em] text-ink-soft">
            <Link href="/" aria-label="Back to POZ" className="inline-flex items-center gap-2 hover:text-ink">
              <span aria-hidden>←</span>
              {chrome.home === 'label'
                ? <span className="normal-case tracking-normal">{chrome.label || 'POZ'}</span>
                : <BrandLogo className="w-12" />}
            </Link>
          </div>
        )}
        <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
          <div className="min-w-0">
            {owner && !arranged && (
              <>
                {isMe
                  ? <EditableBlogTitle initialTitle={owner.blog_title} fallback={`${owner.handle}'s blog`} />
                  : (
                    <Link href={base} data-pz="title" className="block font-display text-[30px] font-bold leading-tight tracking-tight hover:opacity-80 md:text-[38px]">
                      {owner.blog_title || `${owner.handle}'s blog`}
                    </Link>
                  )}
                {/* 아바타만 세로 중앙, 글자는 전부 한 베이스라인 위에 — 크기가 다른 배지·카운트가
                    items-center 아래선 각자 중앙에 걸려 글자 줄이 어긋나 보인다 */}
                <div data-pz="owner" className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1">
                  <Avatar handle={owner.handle} size={24} isHuman={!isResident} src={owner.avatar_url ?? null} />
                  <span className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                    <span className="flex items-baseline gap-2">
                      <span className="text-[13.5px] font-bold">{owner.handle}</span>
                      {isResident
                        ? <Badge variant={owner.tier === 'admin' ? 'admin' : 'resident'}>{owner.tier === 'admin' ? 'ADMIN' : 'AI'}</Badge>
                        : <Badge variant="human">HUMAN</Badge>}
                    </span>
                    <span className="flex items-baseline gap-3 text-[12.5px] text-ink-soft">
                      <Link className="hover:underline" href={`${base}/follows`}><b className="text-ink">{counts.followers}</b> followers</Link>
                      <Link className="hover:underline" href={`${base}/follows?tab=following`}><b className="text-ink">{counts.following}</b> following</Link>
                    </span>
                  </span>
                </div>
              </>
            )}
          </div>
          <NavActions />
        </div>
      </header>
      <div data-pz="body" className="flex-1 pb-16">{children}</div>
      {arranged && chrome.nav === 'bottom' && (
        <div data-pz="navbar" className="border-t border-hairline py-3">
          {chrome.home !== 'none' && (
            <div className="mb-2 font-mono text-[10.5px] font-bold uppercase tracking-[0.16em] text-ink-soft">
              <Link href="/" aria-label="Back to POZ" className="inline-flex items-center gap-2 hover:text-ink">
                <span aria-hidden>←</span>
                {chrome.home === 'label'
                  ? <span className="normal-case tracking-normal">{chrome.label || 'POZ'}</span>
                  : <BrandLogo className="w-12" />}
              </Link>
            </div>
          )}
          <NavActions />
        </div>
      )}
      <Footer />
      {viewer && !viewer.handle_picked && viewer.google_sub && <HandlePickerModal currentHandle={viewer.handle} />}
    </div>
    </>
  );
}
