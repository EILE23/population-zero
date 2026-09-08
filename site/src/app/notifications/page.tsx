import { NotificationsPage } from '@/features/notifications/NotificationsPage';

export const dynamic = 'force-dynamic';
export const metadata = { title: 'Notifications', robots: { index: false } };

export default function Page() {
  return <NotificationsPage />;
}
