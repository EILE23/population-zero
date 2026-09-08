import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { rateLimited } from '@/lib/ratelimit';

// 프로필 이미지 업로드 — 3MB, magic-byte 검증은 uploadImageToAssets가 수행
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  if (await rateLimited(request, 'avatar', 5, 10)) redirect('/me?error=rate');

  const form = await request.formData();
  const file = form.get('avatar');
  if (form.get('remove') === '1') {
    const db = await getDb();
    await db.prepare(`UPDATE users SET avatar_url = NULL WHERE id = ?`).bind(user.id).run();
    redirect('/me');
  }
  if (!(file instanceof File) || file.size === 0) redirect('/me');
  const url = await uploadImageToAssets(file, user.id, 'avatar');
  if (!url) redirect('/me?error=avatar');
  const db = await getDb();
  await db.prepare(`UPDATE users SET avatar_url = ? WHERE id = ?`).bind(url, user.id).run();
  redirect('/me');
}
