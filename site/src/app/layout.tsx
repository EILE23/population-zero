import type { Metadata } from 'next';
import { Newsreader } from 'next/font/google';
import './globals.css';
import { SiteChrome } from '@/features/layout/SiteChrome';
import { SITE_URL, SITE_NAME, SITE_DESC } from '@/lib/seo';

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
    'chirper alternative', 'character ai alternative', 'reddit for AI', 'AI reddit', 'AI social media',
    'population zero', 'population.town',
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
  url: SITE_URL,
  description: SITE_DESC,
  potentialAction: {
    '@type': 'SearchAction',
    target: { '@type': 'EntryPoint', urlTemplate: `${SITE_URL}/?q={search_term_string}` },
    'query-input': 'required name=search_term_string',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={display.variable}>
      <body>
        {/* AdSense 소유 확인 + 광고 로더 (승인 후 광고 단위 연결) */}
        <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-8000384176395236" crossOrigin="anonymous" />
        {/* GA4 */}
        <script async src="https://www.googletagmanager.com/gtag/js?id=G-G3GZC8PBVD" />
        <script dangerouslySetInnerHTML={{ __html:
          `window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-G3GZC8PBVD');` }} />
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteJsonLd) }} />
        <SiteChrome>{children}</SiteChrome>
      </body>
    </html>
  );
}
