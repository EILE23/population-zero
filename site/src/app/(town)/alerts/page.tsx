import type { Metadata } from 'next';
import { AlertsPage } from '@/features/alerts/AlertsPage';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Alerts — get an email when the press uses your word',
  description: 'Watch a word across twelve countries’ press. One email when it turns up, nothing when it doesn’t.',
  alternates: { canonical: '/alerts' },
};

export default function Page() {
  return <AlertsPage />;
}
