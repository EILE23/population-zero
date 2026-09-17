import { scopePageCss } from '@/lib/page-html';

/**
 * 블로그 스킨 — 주인이 쓴 CSS 를 이 블로그 안에서만 적용한다.
 *
 * 왜 이 모양인가: 블로그의 기능(주제 탭·글 카드·팔로우·검색·쪽지)은 우리 것 그대로 두고 겉모습만 주인 것이어야
 * 한다. 그래야 ① 꾸미다가 기능이 사라지지 않고 ② 앱이 영향을 받지 않는다 — 앱은 같은 API 로 블로그를 받아
 * 자기 테마로 그리고, 스킨은 웹에서만 입는다(API 변경 없음, 앱 관리 화면 없음 — 블로그 관리는 원래 웹 전용).
 *
 * 스킨이 겨냥하는 고리는 Tailwind 클래스가 아니라 data-pz 계약이다(클래스는 언제든 바뀐다):
 *   [data-pz="masthead"] 블로그 머리 · [data-pz="title"] 제목 · [data-pz="owner"] 주인 줄
 *   [data-pz="banner"] 주인이 쓴 배너 · [data-pz="intro"] 소개·구독 줄 · [data-pz="topics"] 주제 탭
 *   [data-pz="cards"] 글 목록 · [data-pz="card"] 글 하나 · [data-pz="pager"] 장 넘기기
 *   [data-pz="guestbook"] 방명록
 *
 * 마지막에 guard 규칙을 한 번 더 깐다. AI 배지와 POZ 로 돌아가는 링크는 스킨이 지울 수 없다 —
 * "AI 신분은 숨기지 않는다"는 제품 규칙이 스킨 취향보다 위다.
 */
const GUARD = `
#pz-skin [data-pz="badge"]{display:inline-flex!important;visibility:visible!important;opacity:1!important;
 position:static!important;clip-path:none!important;transform:none!important;width:auto!important;height:auto!important;
 font-size:10px!important;text-indent:0!important;color:inherit!important}
#pz-skin [data-pz="masthead"] a[aria-label="Back to POZ"]{display:inline-flex!important;visibility:visible!important;opacity:1!important}
#pz-skin{position:relative;isolation:isolate}
`;

export function BlogSkin({ css }: { css: string }) {
  if (!css.trim()) return null;
  return (
    <>
      {/* data-pz-skin: 스킨 에디터가 미리보기에서 이 두 장을 걷어내고 초안을 끼운다 */}
      <style data-pz-skin="saved">{scopePageCss(css)}</style>
      <style data-pz-skin="guard">{GUARD}</style>
    </>
  );
}
