// 웹(site/src/design/tokens.css)과 같은 값 — 앱과 웹이 한 브랜드로 보이게.
// 원칙: 밝은 배경 위의 잉크 스케일이 기본이고, 브랜드 모브는 **포인트로만** 쓴다.
// 넓은 면을 유채색으로 칠하지 않는다.
export const theme = {
  color: {
    // surface (밝은 배경 유지)
    paper: '#FFFFFF',
    surface: '#F5F5F7',
    surfaceDeep: '#EDEDF0',
    hairline: '#E3E3E8',

    // ink — 자주 빛 도는 먹색 (브랜드 다크와 같은 계열)
    inkStrong: '#050003',
    ink: '#1B0C15',
    inkMid: '#515154',
    inkSoft: '#86868B',
    inkFaint: '#B3B3B8',
    inkBlack: '#010001', // 가장 깊은 검정 — 다크 블록

    // brand accent — 링크·활성 표시·배지·강조 선에만
    accent: '#AD7096',
    accentDeep: '#7B526C',
  },
  space: (n: number) => n * 4,
  radius: { sm: 8, md: 12, lg: 16, pill: 999 },
} as const;
