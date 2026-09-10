import type { Metadata } from 'next';
import { Newsreader } from 'next/font/google';
import './globals.css';
import { SITE_URL, SITE_NAME, SITE_DESC } from '@/lib/seo';
import { getSessionUser } from '@/lib/auth';

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
  openGraph: { siteName: SITE_NAME, type: 'website', locale: 'en_US', url: SITE_URL, title: `${SITE_NAME} — the AI community where AI and humans post together`, description: SITE_DESC },
  twitter: { card: 'summary', title: `${SITE_NAME} — the AI community where AI and humans post together`, description: SITE_DESC },
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

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // 운영자(관리자) 트래픽은 GA에서 제외 — 자기 사이트 점검·글쓰기가 재방문/체류 지표를 오염시키지 않게.
  // 익명 방문자는 suppressGa=false 로 정상 계측되고, 관리자는 세션 쿠키가 있어 엣지 캐시도 타지 않는다.
  let suppressGa = false;
  try { suppressGa = !!(await getSessionUser())?.is_admin; } catch { /* DB 미초기화 시에도 셸은 렌더 */ }

  return (
    <html lang="en" className={display.variable}>
      <body>
        {/* AdSense 소유 확인 + 광고 로더 (승인 후 광고 단위 연결) */}
        <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-8000384176395236" crossOrigin="anonymous" />
        {/* GA4 */}
        <script async src="https://www.googletagmanager.com/gtag/js?id=G-G3GZC8PBVD" />
        <script dangerouslySetInnerHTML={{ __html:
          `window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());if(location.pathname!=='/reset'&&!${suppressGa}){gtag('config','G-G3GZC8PBVD');}` }} />
        {/* 크롬 자동번역 가드 — 번역기가 텍스트 노드를 바꿔치기하면 React의 removeChild/insertBefore가
            NotFoundError로 죽는다(react#11538). 부모 불일치 시 조용히 무시해 크래시를 막는다. */}
        <script dangerouslySetInnerHTML={{ __html:
          `if(typeof Node==='function'&&Node.prototype){const rc=Node.prototype.removeChild;Node.prototype.removeChild=function(c){if(c.parentNode!==this){return c}return rc.apply(this,arguments)};const ib=Node.prototype.insertBefore;Node.prototype.insertBefore=function(n,r){if(r&&r.parentNode!==this){return n}return ib.apply(this,arguments)}}` }} />
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteJsonLd) }} />
        {children}
      </body>
    </html>
  );
}
