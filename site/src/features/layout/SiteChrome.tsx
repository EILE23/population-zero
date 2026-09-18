import { Masthead } from './Masthead';
import { Footer } from './Footer';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { parseLayout, themeVars } from '@/lib/blog-layout';
import { HandlePickerModal } from '@/features/auth/HandlePickerModal';

/**
 * 일반 페이지 셸 — 마스트헤드 + 푸터.
 *
 * 로그인해 있으면 **내 블로그 테마가 사이트 전체 스킨**이 된다. 내가 고른 색이 내 블로그에서만 보이고
 * 정작 내가 쓰는 화면은 남의 기본색이면 이상하다 — 다크모드를 자기 블로그에만 켜는 셈이다.
 * 남의 블로그(/@handle)에서는 그 주인 테마가 이긴다: 그 페이지는 그 사람 것이고,
 * [profile]/layout.tsx 가 더 뒤에서 자기 <style> 을 그려 이 값을 덮는다.
 *
 * 비로그인 방문자는 기본색이다. 로그인 요청은 엣지 캐시를 타지 않으므로(worker-entry 의 cacheable)
 * 남의 화면에 내 색이 캐시될 일은 없다.
 */
export async function SiteChrome({ children }: { children: React.ReactNode }) {
  let needsHandle: string | null = null;
  let pageStyle: React.CSSProperties | undefined;
  let pageBg = '';
  try {
    const user = await getSessionUser();
    if (user && !user.handle_picked && user.google_sub) needsHandle = user.handle;
    if (user && !user.guest) {
      const row = await (await getDb())
        .prepare(`SELECT layout FROM pages WHERE user_id = ? AND layout IS NOT NULL`)
        .bind(user.id).first<{ layout: string }>();
      if (row) {
        const theme = parseLayout(row.layout).theme;
        pageStyle = themeVars(theme) as React.CSSProperties;
        pageBg = theme.bg;   // #hex 검증을 통과한 값만 들어온다(cleanLayout)
      }
    }
  } catch { /* DB 미초기화 시에도 셸은 렌더 */ }

  return (
    <>
      {pageBg && <style>{`body{background:${pageBg}}`}</style>}
      <div
        style={pageStyle}
        className={`mx-auto flex min-h-svh max-w-7xl flex-col overflow-x-clip px-5 md:px-8 ${pageBg ? 'pz-page' : ''}`}
      >
        <Masthead />
        <div className="flex-1 pb-16">{children}</div>
        <Footer />
        {needsHandle && <HandlePickerModal currentHandle={needsHandle} />}
      </div>
    </>
  );
}
