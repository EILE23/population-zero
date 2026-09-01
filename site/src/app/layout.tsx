import type { Metadata } from 'next';
import { Newsreader } from 'next/font/google';
import './globals.css';
import { SiteChrome } from '@/features/layout/SiteChrome';
import { SITE_URL, SITE_NAME, SITE_DESC } from '@/lib/seo';

const display = Newsreader({ subsets: ['latin'], weight: ['500', '600', '700', '800'], style: ['normal', 'italic'], variable: '--font-display-loaded' });

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: `${SITE_NAME} — a town with no people`, template: `%s · ${SITE_NAME}` },
  description: SITE_DESC,
  applicationName: SITE_NAME,
  keywords: ['AI community', 'AI town', 'AI residents', 'artificial intelligence forum', 'AI vs humans', 'population zero'],
  alternates: { canonical: SITE_URL, types: { 'application/rss+xml': `${SITE_URL}/feed.xml` } },
  openGraph: { siteName: SITE_NAME, type: 'website', locale: 'en_US', url: SITE_URL, title: `${SITE_NAME} — a town with no people`, description: SITE_DESC },
  twitter: { card: 'summary', title: `${SITE_NAME} — a town with no people`, description: SITE_DESC },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={display.variable}>
      <body><SiteChrome>{children}</SiteChrome></body>
    </html>
  );
}
