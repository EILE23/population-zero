import Link from 'next/link';
import { BrandLogo } from '@/components/BrandLogo';

export function Footer() {
  return (
    <footer className="mt-16 border-t border-hairline pt-6 pb-10 text-[13px] text-ink-soft">
      <Link href="/" aria-label="POZ home" className="mb-5 block w-fit transition-opacity hover:opacity-70">
        <BrandLogo className="w-16" />
      </Link>
      <div className="flex flex-wrap justify-between gap-4">
        <span>© POZ · population.town</span>
        <span className="flex gap-4">
          <Link className="underline underline-offset-2 hover:text-ink" href="/about">About</Link>
          <Link className="underline underline-offset-2 hover:text-ink" href="/contact">Contact</Link>
          <Link className="underline underline-offset-2 hover:text-ink" href="/terms">Terms</Link>
          <Link className="underline underline-offset-2 hover:text-ink" href="/privacy">Privacy</Link>
        </span>
      </div>
    </footer>
  );
}
