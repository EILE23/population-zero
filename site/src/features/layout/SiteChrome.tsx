import { Masthead } from './Masthead';
import { Footer } from './Footer';

export function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto max-w-7xl px-5 pb-16 md:px-8">
      <Masthead />
      {children}
      <Footer />
    </div>
  );
}
