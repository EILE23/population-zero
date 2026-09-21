import { getDb, getEnv } from '@/lib/db';

const IMAGE_TYPES: Record<string, string> = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/gif': 'gif' };
const VIDEO_TYPES: Record<string, string> = { 'video/webm': 'webm', 'video/mp4': 'mp4' };
const IMAGE_MAX = 3 * 1024 * 1024; // 3MB
const MEME_MAX = 8 * 1024 * 1024;  // 짤·GIF 는 크다 (jsDelivr 는 20MB 까지 배달한다)
const CLIP_MAX = 12 * 1024 * 1024; // 릴(브라우저가 녹화한 WebM/MP4, 30초 ≈ 2~6MB)

export type AssetKind = 'cover' | 'inline' | 'avatar' | 'meme' | 'clip';

/** 사용자 파일 업로드 → 공개 자산 레포(pz-assets) → jsDelivr CDN URL. 실패 시 null (글 발행은 막지 않는다). clip 만 영상을 받는다 */
export async function uploadImageToAssets(file: File, userId: number, kind: AssetKind = 'cover'): Promise<string | null> {
  try {
    const ext = kind === 'clip' ? VIDEO_TYPES[file.type] : IMAGE_TYPES[file.type];
    const max = kind === 'clip' ? CLIP_MAX : kind === 'meme' ? MEME_MAX : IMAGE_MAX;
    if (!ext || file.size === 0 || file.size > max) return null;
    const { PZ_ASSETS_PAT } = await getEnv();
    if (!PZ_ASSETS_PAT) return null;
    const buf = new Uint8Array(await file.arrayBuffer());
    // magic-byte 검증 — 브라우저가 보낸 MIME 문자열은 위조 가능하므로 실제 시그니처를 본다
    if (!(kind === 'clip' ? validVideo(file.type, buf) : validImage(file.type, buf))) return null;
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

/** WebM 은 EBML 헤더(1A 45 DF A3), MP4 는 4바이트 뒤 'ftyp' */
export function validVideo(mime: string, buf: Uint8Array): boolean {
  const ext = VIDEO_TYPES[mime];
  return (ext === 'webm' && buf[0] === 0x1a && buf[1] === 0x45 && buf[2] === 0xdf && buf[3] === 0xa3) ||
      (ext === 'mp4' && buf[4] === 0x66 && buf[5] === 0x74 && buf[6] === 0x79 && buf[7] === 0x70);
}
