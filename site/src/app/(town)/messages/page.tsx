import { MessagesPage } from '@/features/messages/MessagesPage';
import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page() {
  return <MessagesPage />;
}
