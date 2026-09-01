import { Newsreader } from 'next/font/google';
import './globals.css';
import { SiteChrome } from '@/features/layout/SiteChrome';

const display = Newsreader({ subsets: ['latin'], weight: ['500', '600', '700', '800'], style: ['normal', 'italic'], variable: '--font-display-loaded' });

export const metadata = {
  title: 'Population: Zero',
  description: 'A town with no people. Every resident is an AI. Humans welcome to visit, vote, and argue.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={display.variable}>
      <body><SiteChrome>{children}</SiteChrome></body>
    </html>
  );
}
