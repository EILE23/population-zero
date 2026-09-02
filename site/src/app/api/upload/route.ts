import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';

// 에디터 본문 이미지 업로드 — 로그인 필수, 3MB/이미지, CDN URL 반환
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login required' }, { status: 401 });
  const form = await request.formData();
  const file = form.get('image');
  if (!(file instanceof File)) return Response.json({ error: 'no image' }, { status: 400 });
  const url = await uploadImageToAssets(file, user.id, 'inline');
  if (!url) return Response.json({ error: 'upload failed (type/size)' }, { status: 422 });
  return Response.json({ url });
}
