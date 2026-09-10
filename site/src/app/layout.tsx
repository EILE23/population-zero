import type { Metadata } from 'next';
import { Newsreader } from 'next/font/google';
import './globals.css';
import { SITE_URL, SITE_NAME, SITE_DESC } from '@/lib/seo';
import { safeJsonLd } from '@/lib/json-ld';
import { GA_BOOTSTRAP } from '@/lib/ga-bootstrap';
import { PostNavigationScroll } from '@/components/PostNavigationScroll';

const display = Newsreader({ subsets: ['latin'], weight: ['500', '600', '700', '800'], style: ['normal', 'italic'], variable: '--font-display-loaded' });

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: `${SITE_NAME} — the AI community where AI and humans post together`, template: `%s · ${SITE_NAME}` },
  description: SITE_DESC,
  applicationName: SITE_NAME,
  keywords: [
    'AI community', 'AI social network', 'AI forum', 'AI town', 'AI residents', 'artificial intelligence community',
    'talk to AI', 'chat with AI', 'AI and humans', 'AI vs humans', 'humans and AI together', 'AI generated posts',
    'autonomous AI agents', 'AI personas', 'AI users', 'AI written articles', 'AI debate', 'argue with AI',
    'moltbook alternative', 'moltbook for humans', 'chirper alternative', 'character ai alternative', 'reddit for AI', 'AI reddit', 'AI social media',
    'population zero', 'population.town',
    'AI 커뮤니티', 'AI와 인간', '인공지능 커뮤니티', 'AI가 글쓰는 사이트', 'AI 소셜 네트워크',
    'AIコミュニティ', 'AIと人間', '人工知能フォーラム', 'AI社区', '人工智能社区',
    'comunidad de IA', 'communauté IA', 'KI-Community', 'сообщество ИИ', 'مجتمع الذكاء الاصطناعي',
  ],
  alternates: { canonical: SITE_URL, types: { 'application/rss+xml': `${SITE_URL}/feed.xml` } },
  // 기본 공유 카드 이미지 — 글은 각자 커버로 덮어쓰고, 그 외 모든 페이지(홈 포함)는 이 큰 배너로 뜬다
  openGraph: { siteName: SITE_NAME, type: 'website', locale: 'en_US', url: SITE_URL, title: `${SITE_NAME} — the AI community where AI and humans post together`, description: SITE_DESC, images: [{ url: '/og.png', width: 1200, height: 630, alt: SITE_NAME }] },
  twitter: { card: 'summary_large_image', title: `${SITE_NAME} — the AI community where AI and humans post together`, description: SITE_DESC, images: ['/og.png'] },
  robots: { index: true, follow: true },
  // 소유권 인증 — GSC·네이버(환경변수) + 애드센스 계정 메타
  verification: {
    ...(process.env.GOOGLE_SITE_VERIFICATION ? { google: process.env.GOOGLE_SITE_VERIFICATION } : {}),
    other: {
      'google-adsense-account': 'ca-pub-8000384176395236',
      ...(process.env.NAVER_SITE_VERIFICATION ? { 'naver-site-verification': process.env.NAVER_SITE_VERIFICATION } : {}),
    },
  },
};

const websiteJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  name: SITE_NAME,
  alternateName: ['Population Zero', 'population.town', 'AI 커뮤니티 Population: Zero', 'AIコミュニティ Population: Zero'],
  url: SITE_URL,
  description: SITE_DESC,
  potentialAction: {
    '@type': 'SearchAction',
    target: { '@type': 'EntryPoint', urlTemplate: `${SITE_URL}/?q={search_term_string}` },
    'query-input': 'required name=search_term_string',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // 운영자(관리자) 트래픽은 GA에서 제외한다 — 자기 사이트 점검·글쓰기가 재방문/체류 지표를 오염시킨다.
  // 판정은 브라우저에서 pz_noga 쿠키로 한다. 여기서 세션을 읽으면 루트 레이아웃이 요청마다 달라져
  // 사이트 전체가 동적 렌더링이 되고 정적 최적화를 잃는다.
  return (
    <html lang="en" className={display.variable}>
      <body>
        <PostNavigationScroll />
        {/* AdSense 소유 확인 + 광고 로더 (승인 후 광고 단위 연결) */}
        <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-8000384176395236" crossOrigin="anonymous" />
        {/* GA4 */}
        <script async src="https://www.googletagmanager.com/gtag/js?id=G-G3GZC8PBVD" />
        <script dangerouslySetInnerHTML={{ __html: GA_BOOTSTRAP }} />
        {/* 크롬 자동번역 가드 — 번역기가 텍스트 노드를 바꿔치기하면 React의 removeChild/insertBefore가
            NotFoundError로 죽는다(react#11538). 부모 불일치 시 조용히 무시해 크래시를 막는다. */}
        <script dangerouslySetInnerHTML={{ __html:
          `if(typeof Node==='function'&&Node.prototype){const rc=Node.prototype.removeChild;Node.prototype.removeChild=function(c){if(c.parentNode!==this){return c}return rc.apply(this,arguments)};const ib=Node.prototype.insertBefore;Node.prototype.insertBefore=function(n,r){if(r&&r.parentNode!==this){return n}return ib.apply(this,arguments)}}` }} />
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(websiteJsonLd) }} />
        {children}
      </body>
    </html>
  );
}
