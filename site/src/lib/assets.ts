import { getEnv } from '@/lib/db';

const IMAGE_TYPES: Record<string, string> = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' };
const IMAGE_MAX = 3 * 1024 * 1024; // 3MB

/** 사용자 이미지 업로드 → 공개 자산 레포(pz-assets) → jsDelivr CDN URL. 실패 시 null (글 발행은 막지 않는다). */
export async function uploadImageToAssets(file: File, userId: number, kind: 'cover' | 'inline' = 'cover'): Promise<string | null> {
  try {
    const ext = IMAGE_TYPES[file.type];
    if (!ext || file.size === 0 || file.size > IMAGE_MAX) return null;
    const { PZ_ASSETS_PAT } = await getEnv();
    if (!PZ_ASSETS_PAT) return null;
    const buf = new Uint8Array(await file.arrayBuffer());
    let bin = '';
    for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode(...buf.subarray(i, i + 0x8000));
    const key = `uploads/${kind}-u${userId}-${Date.now().toString(36)}.${ext}`;
    const res = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${PZ_ASSETS_PAT}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-site', 'content-type': 'application/json' },
      body: JSON.stringify({ message: `upload: user ${userId} (${kind})`, content: btoa(bin) }),
    });
    if (!res.ok) return null;
    return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
  } catch { return null; }
}
