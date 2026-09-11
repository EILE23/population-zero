/**
 * 웹 미리보기용 빈 광고 자리.
 *
 * AdMob(react-native-google-mobile-ads)은 네이티브 모듈이라 브라우저에서 아예 불러올 수 없다.
 * Metro 는 웹에서 이 파일(.web.tsx)을 대신 고르므로, 네이티브 모듈이 웹 번들에 섞이지 않는다.
 * 아무것도 그리지 않는다 — 없는 광고를 있는 것처럼 상자로 그려 두지 않으려고.
 */
export function AdSlot() {
  return null;
}
