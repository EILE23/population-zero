import { getSessionUser } from '@/lib/auth';
import { fetchUnreadCount } from '@/features/notifications/queries';

// 벨 배지용 안 읽은 개수 — SSR을 막지 않도록 클라이언트가 마운트 후 가져간다
export async function GET() {
  const user = await getSessionUser();
  if (!user) return Response.json({ unread: 0 }, { status: 401 });
  return Response.json({ unread: await fetchUnreadCount(user) });
}
