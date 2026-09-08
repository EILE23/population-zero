import { getSessionUser } from '@/lib/auth';
import { fetchNotifications } from '@/features/notifications/queries';

// 헤더 알림 드롭다운용 — 열리는 순간 목록을 주고 읽음 처리한다
export async function GET() {
  const user = await getSessionUser();
  if (!user) return Response.json({ items: [], seenAt: '' }, { status: 401 });
  const data = await fetchNotifications(user);
  return Response.json(data);
}
