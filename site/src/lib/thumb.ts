/**
 * 벽용 섬네일 — 브라우저에서 480px 폭 WebP(안 되면 JPEG)로 줄인다. 원본 PNG 는 한 장 0.4~1MB 라 80장이 걸리는 벽이 느렸다.
 * 소스: 그림판 캔버스, 올린 그림(<img>), 영상의 첫 프레임 캔버스. 실패하면 null — 그러면 벽은 원본을 쓴다.
 */
export const THUMB_W = 480;
export function thumbBlob(src: HTMLCanvasElement | HTMLImageElement | HTMLVideoElement, maxW = THUMB_W): Promise<Blob | null> {
  return new Promise((ok) => {
    try {
      const sw = src instanceof HTMLVideoElement ? src.videoWidth : src instanceof HTMLImageElement ? src.naturalWidth : src.width;
      const sh = src instanceof HTMLVideoElement ? src.videoHeight : src instanceof HTMLImageElement ? src.naturalHeight : src.height;
      if (!sw || !sh) return ok(null);
      const k = Math.min(1, maxW / sw);
      const c = document.createElement('canvas'); c.width = Math.max(1, Math.round(sw * k)); c.height = Math.max(1, Math.round(sh * k));
      const ctx = c.getContext('2d'); if (!ctx) return ok(null);
      ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, c.width, c.height); // 투명은 흰 바탕으로 — JPEG 대비용
      ctx.drawImage(src, 0, 0, c.width, c.height);
      c.toBlob((b) => { if (b && b.type === 'image/webp') return ok(b); c.toBlob((j) => ok(j), 'image/jpeg', 0.82); }, 'image/webp', 0.8);
    } catch { ok(null); }
  });
}
/** 파일(그림)에서 섬네일 — GIF 는 첫 프레임이 찍힌다 */
export function thumbFromFile(file: File): Promise<Blob | null> {
  return new Promise((ok) => {
    const im = new Image(); const url = URL.createObjectURL(file);
    im.onload = () => { void thumbBlob(im).then((b) => { URL.revokeObjectURL(url); ok(b); }); };
    im.onerror = () => { URL.revokeObjectURL(url); ok(null); };
    im.src = url;
  });
}
