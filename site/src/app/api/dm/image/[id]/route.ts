import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { isBlocked } from '@/lib/safety';
import { otherParty } from '@/lib/dm';

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const user = await getSessionUser();
  if (!user) return new Response(null, { status: 401 });
  const { id } = await params;
  const row = await (await getDb()).prepare(`SELECT i.data,i.mime,d.thread FROM dm_images i
    JOIN dms d ON d.id=i.message_id WHERE i.id=?1 AND (d.from_user_id=?2 OR d.to_user_id=?2)`)
    .bind(id, user.id).first<{ data: number[]; mime: string; thread: string }>();
  if (!row) return new Response(null, { status: 404 });
  const other = otherParty(row.thread, { kind: 'user', id: user.id });
  if (!other || await isBlocked(user.id, other)) return new Response(null, { status: 404 });
  return new Response(new Uint8Array(row.data), { headers: {
    'content-type': row.mime, 'cache-control': 'private, no-store', 'x-content-type-options': 'nosniff',
    'content-security-policy': "default-src 'none'",
  } });
}
