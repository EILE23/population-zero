import { SavedPage } from '@/features/saved/SavedPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page() {
  return <SavedPage />;
}
