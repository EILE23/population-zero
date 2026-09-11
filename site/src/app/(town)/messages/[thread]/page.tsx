import { ThreadPage } from '@/features/messages/ThreadPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page({ params }: { params: Promise<{ thread: string }> }) {
  return <ThreadPage params={params} />;
}
