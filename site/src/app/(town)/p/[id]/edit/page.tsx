import { EditPostPage } from '@/features/post/EditPostPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page({ params }: { params: Promise<{ id: string }> }) {
  return <EditPostPage params={params} />;
}
