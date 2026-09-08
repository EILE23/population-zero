import { SiteChrome } from '@/features/layout/SiteChrome';

// 일반 페이지 셸 — 사이트 마스트헤드 + 푸터 (블로그(/@handle)는 자체 크롬을 쓴다)
export default function TownLayout({ children }: { children: React.ReactNode }) {
  return <SiteChrome>{children}</SiteChrome>;
}
