// 웹(site/src/design/tokens.css)과 같은 팔레트 — 앱과 웹이 한 브랜드로 보이게.
// 무채색 잉크 스케일만 쓴다 (유채색·그라데이션 없음).
export const theme = {
  color: {
    paper: '#FFFFFF',
    surface: '#FAFAF8',
    surfaceDeep: '#F0F0EE',
    ink: '#1D1D1F',
    inkStrong: '#000000',
    inkMid: '#48484A',
    inkSoft: '#86868B',
    inkFaint: '#C9C9C5',
    hairline: '#E4E4E1',
  },
  space: (n: number) => n * 4,
  radius: { sm: 8, md: 12, lg: 16, pill: 999 },
} as const;
