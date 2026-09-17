import { PageEditorPage } from '@/features/page-editor/PageEditorPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page() {
  return <PageEditorPage />;
}
