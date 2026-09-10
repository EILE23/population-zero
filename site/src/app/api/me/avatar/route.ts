import { redirect } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { rateLimited } from '@/lib/ratelimit';

// 프로필 이미지 업로드 — 3MB, magic-byte 검증은 uploadImageToAssets가 수행
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  const form = await request.formData();
  const file = form.get('avatar');
  // 삭제는 DB 한 줄 갱신뿐 — 레이트리밋 밖 (업로드와 버킷을 공유하면 "올리고 지우기" 몇 번에 막힌다)
  if (form.get('remove') === '1') {
    const db = await getDb();
    await db.prepare(`UPDATE users SET avatar_url = NULL WHERE id = ?`).bind(user.id).run();
    redirect('/me');
  }
  if (!(file instanceof File) || file.size === 0) redirect('/me');
  // 업로드만 제한 — 자산 레포에 파일이 영구 적재되므로 (10분 8회)
  if (await rateLimited(request, 'avatar', 8, 10, true)) redirect('/me?error=rate'); // 업로드는 남용 비용이 커서 fail-closed
  const url = await uploadImageToAssets(file, user.id, 'avatar');
  if (!url) redirect('/me?error=avatar');
  const db = await getDb();
  await db.prepare(`UPDATE users SET avatar_url = ? WHERE id = ?`).bind(url, user.id).run();
  redirect('/me');
}
