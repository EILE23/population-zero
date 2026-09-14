import { getDb, getEnv } from '@/lib/db';

const IMAGE_TYPES: Record<string, string> = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' };
const IMAGE_MAX = 3 * 1024 * 1024; // 3MB

/** 사용자 이미지 업로드 → 공개 자산 레포(pz-assets) → jsDelivr CDN URL. 실패 시 null (글 발행은 막지 않는다). */
export async function uploadImageToAssets(file: File, userId: number, kind: 'cover' | 'inline' | 'avatar' = 'cover'): Promise<string | null> {
  try {
    const ext = IMAGE_TYPES[file.type];
    if (!ext || file.size === 0 || file.size > IMAGE_MAX) return null;
    const { PZ_ASSETS_PAT } = await getEnv();
    if (!PZ_ASSETS_PAT) return null;
    const buf = new Uint8Array(await file.arrayBuffer());
    // magic-byte 검증 — 브라우저가 보낸 MIME 문자열은 위조 가능하므로 실제 시그니처를 본다
    if (!validImage(file.type, buf)) return null;
    let bin = '';
    for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode(...buf.subarray(i, i + 0x8000));
    const key = `uploads/${kind}-u${userId}-${Date.now().toString(36)}.${ext}`;
    const res = await fetch(`https://api.github.com/repos/EILE23/pz-assets/contents/${key}`, {
      method: 'PUT',
      headers: { authorization: `Bearer ${PZ_ASSETS_PAT}`, accept: 'application/vnd.github+json', 'user-agent': 'pz-site', 'content-type': 'application/json' },
      body: JSON.stringify({ message: `upload: user ${userId} (${kind})`, content: btoa(bin) }),
    });
    if (!res.ok) return null;
    // 소유 원장 — 이 파일이 나중에 어떤 글에서도 참조되지 않게 되더라도(글 삭제·아바타 교체) 탈퇴 때 정리 대상이 되게.
    // 원장 기록 실패는 업로드를 되돌리지 않는다: 파일은 이미 올라갔고, 없는 것보다 참조로라도 찾히는 편이 낫다.
    try { await (await getDb()).prepare(`INSERT OR IGNORE INTO user_assets (path, user_id) VALUES (?, ?)`).bind(key, userId).run(); } catch { /* 위 주석 */ }
    return `https://cdn.jsdelivr.net/gh/EILE23/pz-assets@main/${key}`;
  } catch { return null; }
}

export function validImage(mime: string, buf: Uint8Array): boolean {
  const ext = IMAGE_TYPES[mime];
  return (ext === 'png' && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) ||
      (ext === 'jpg' && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) ||
      (ext === 'gif' && buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x38) ||
      (ext === 'webp' && buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 && buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50);

}
