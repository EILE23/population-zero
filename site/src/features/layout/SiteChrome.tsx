import { Masthead } from './Masthead';
import { Footer } from './Footer';

export function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <div className="mx-auto flex min-h-svh max-w-7xl flex-col px-5 md:px-8">
      <Masthead />
      <div className="flex-1 pb-16">{children}</div>
      <Footer />
    </div>
  );
}
