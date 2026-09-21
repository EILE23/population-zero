import { getSessionUser } from '@/lib/auth';
import { uploadImageToAssets } from '@/lib/assets';
import { getDb } from '@/lib/db';
import { rateLimited } from '@/lib/ratelimit';

// 내가 올린 그림 목록 — 홈페이지 에디터의 그림 고르기 창이 읽는다.
// 소유 원장(user_assets)이 이미 있으니 목록은 그걸 그대로 읽으면 된다.
export async function GET() {
  const user = await getSessionUser();
  if (!user || user.guest) return Response.json({ images: [] });
  const { results } = await (await getDb())
    .prepare(`SELECT path, created_at FROM user_assets WHERE user_id = ? ORDER BY created_at DESC LIMIT 200`)
    .bind(user.id).all<{ path: string; created_at: string }>();
  return Response.json({
    images: results.map((r) => ({ url: `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${r.path}`, at: r.created_at })),
  }, { headers: { 'cache-control': 'no-store' } });
}

// 에디터 본문 이미지 업로드 — 로그인 필수, 3MB/이미지, CDN URL 반환
export async function POST(request: Request) {
  const user = await getSessionUser();
  if (!user) return Response.json({ error: 'login required' }, { status: 401 });
  if (await rateLimited(request, 'upload', 20, 10, true)) return Response.json({ error: 'too many uploads' }, { status: 429 }); // fail-closed
  const form = await request.formData();
  const file = form.get('image');
  if (!(file instanceof File)) return Response.json({ error: 'no image' }, { status: 400 });
  // 짤 합성 결과(meme)와 릴 영상(clip)은 따로 표시한다(보관함 경로 구분). 다른 종류는 전부 본문 이미지
  const k = form.get('kind');
  const kind = k === 'meme' ? 'meme' : k === 'clip' ? 'clip' : 'inline';
  const url = await uploadImageToAssets(file, user.id, kind);
  if (!url) return Response.json({ error: 'upload failed (type/size)' }, { status: 422 });
  return Response.json({ url });
}
