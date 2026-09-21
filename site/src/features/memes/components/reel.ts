import type { MemeSticker, MemeText } from '@/lib/memes';
import { drawMemeText, drawSticker } from '@/lib/meme-draw';

/**
 * 릴 — 세로 컷 스토리보드를 움직이는 영상으로.
 *
 * 컷 하나가 장면 하나다. 세로(9:16) 프레임에 그림을 폭 맞춤으로 넣고(뒤는 같은 그림을 흐리게), 글자는 위에서부터
 * 한 줄씩 '팍' 뜨고(0.7초 간격), 그림은 장면 내내 천천히 줌인. 장면 사이는 컷. 30초 상한.
 * 글자·스티커 좌표는 스토리보드(세로로 이어 붙인 띠) 기준이라 어느 컷 안에 있느냐로 장면이 정해진다 —
 * 편집기에서 보이는 그대로가 대본이다.
 *
 * 녹화는 canvas.captureStream + MediaRecorder(WebM, 사파리는 MP4). 실시간으로 그리므로 30초짜리는 30초 걸린다.
 */
export const FRAME_W = 720, FRAME_H = 1280, FPS = 30, MAX_SEC = 30;

export interface Scene {
  im: CanvasImageSource | null; // 컷 그림(없으면 흰 판)
  h: number;                    // 띠 안에서 이 컷의 높이(px)
  top: number;                  // 띠 안에서 이 컷의 시작 y(px)
  texts: MemeText[];            // 이 컷 안의 글자(띠 좌표 그대로)
  stickers: MemeSticker[];
  start: number; dur: number;   // 초
}

/** 띠(W×H) 를 장면들로 자른다 — 글자·스티커는 중심 y 가 속한 컷으로 */
export function storyboard(panels: (CanvasImageSource | null)[], heights: number[], H: number, texts: MemeText[], stickers: MemeSticker[]): Scene[] {
  const scenes: Scene[] = []; let top = 0, t = 0;
  heights.forEach((h, i) => {
    const inCut = (y: number) => y * H >= top && y * H < top + h;
    const ts = texts.filter((x) => inCut(x.y)).sort((a, b) => a.y - b.y);
    const ss = stickers.filter((x) => inCut(x.y));
    const dur = Math.max(2.2, 1.0 + 0.7 * ts.length + 1.4);
    scenes.push({ im: panels[i], h, top, texts: ts, stickers: ss, start: t, dur });
    t += dur; top += h;
  });
  // 30초 넘으면 장면을 고르게 줄인다
  if (t > MAX_SEC) { const k = MAX_SEC / t; let s = 0; for (const sc of scenes) { sc.start = s; sc.dur *= k; s += sc.dur; } }
  return scenes;
}
export const totalSec = (scenes: Scene[]) => scenes.length ? scenes[scenes.length - 1].start + scenes[scenes.length - 1].dur : 0;

const ease = (u: number) => 1 - Math.pow(1 - Math.min(1, Math.max(0, u)), 3);

/** 한 프레임 — time 초 시점. W 는 띠의 폭(편집기 900), paint 는 붓질층(띠 크기) */
export function drawFrame(ctx: CanvasRenderingContext2D, scenes: Scene[], time: number, W: number, paint: CanvasImageSource | null, stImgs: Map<string, CanvasImageSource & { width: number; height: number }>) {
  const sc = scenes.find((s) => time >= s.start && time < s.start + s.dur) ?? scenes[scenes.length - 1];
  if (!sc) return;
  const u = (time - sc.start) / sc.dur; // 장면 안 진행도 0~1
  const ih = FRAME_W * sc.h / W;        // 프레임 안 그림 높이
  const oy = (FRAME_H - ih) / 2;
  ctx.clearRect(0, 0, FRAME_W, FRAME_H);
  // 뒤: 같은 그림을 꽉 채워 흐리게 — 가로 그림이 세로 프레임에 떠 있지 않게
  ctx.fillStyle = '#111'; ctx.fillRect(0, 0, FRAME_W, FRAME_H);
  if (sc.im) {
    ctx.save(); ctx.filter = 'blur(28px) brightness(0.45)';
    const cover = Math.max(FRAME_W / sc.h * (sc.h / (ih / FRAME_W)) , 1); void cover;
    const s = Math.max(FRAME_W / W, FRAME_H / sc.h) * 1.15; const bw = W * s, bh = sc.h * s;
    ctx.drawImage(sc.im, (FRAME_W - bw) / 2, (FRAME_H - bh) / 2, bw, bh);
    ctx.restore();
  }
  // 그림: 천천히 줌인(1 → 1.06)
  const z = 1 + 0.06 * u;
  ctx.save();
  ctx.translate(FRAME_W / 2, oy + ih / 2); ctx.scale(z, z); ctx.translate(-FRAME_W / 2, -(oy + ih / 2));
  ctx.fillStyle = '#fff'; ctx.fillRect(0, oy, FRAME_W, ih);
  if (sc.im) ctx.drawImage(sc.im, 0, oy, FRAME_W, ih);
  // 스티커: 장면 시작 0.3초에 팍
  const H = sc.top + sc.h; void H;
  const stripH = scenes.reduce((a, s) => a + s.h, 0);
  const local = (o: { x: number; y: number }) => ({ x: o.x, y: (oy + ((o.y * stripH - sc.top) / sc.h) * ih) / FRAME_H });
  sc.stickers.forEach((s) => {
    const im = stImgs.get(s.url); if (!im) return;
    const p = ease((u * sc.dur - 0.3) / 0.25); if (p <= 0) return;
    const l = local(s);
    ctx.save(); ctx.translate(l.x * FRAME_W, l.y * FRAME_H); ctx.scale(0.6 + 0.4 * p, 0.6 + 0.4 * p); ctx.translate(-l.x * FRAME_W, -l.y * FRAME_H);
    ctx.globalAlpha = p; drawSticker(ctx, { ...s, ...l }, im, FRAME_W, FRAME_H); ctx.restore();
  });
  if (paint) ctx.drawImage(paint, 0, sc.top, W, sc.h, 0, oy, FRAME_W, ih);
  ctx.restore();
  // 글자: 위에서부터 0.7초 간격으로, 1.3배에서 튀어 들어온다
  sc.texts.forEach((t, i) => {
    const at = 0.5 + 0.7 * i;
    const p = ease((u * sc.dur - at) / 0.18); if (p <= 0) return;
    const l = local(t);
    const size = (t.size * stripH * (FRAME_W / W)) / FRAME_H; // 띠에서의 px 크기를 프레임 비율로
    const k = 1.3 - 0.3 * p;
    ctx.save(); ctx.translate(l.x * FRAME_W, l.y * FRAME_H); ctx.scale(k, k); ctx.translate(-l.x * FRAME_W, -l.y * FRAME_H);
    ctx.globalAlpha = p; drawMemeText(ctx, { ...t, ...l, size }, FRAME_W, FRAME_H); ctx.restore();
  });
}

/** 녹화 — 실시간으로 그리며 MediaRecorder 로 받는다. 진행도 콜백(0~1). 결과: 영상 Blob + 첫 장면 포스터 PNG */
export async function record(
  scenes: Scene[], W: number, paint: CanvasImageSource | null, stImgs: Map<string, CanvasImageSource & { width: number; height: number }>,
  onProgress: (p: number) => void,
): Promise<{ video: Blob; poster: Blob; mime: string }> {
  const c = document.createElement('canvas'); c.width = FRAME_W; c.height = FRAME_H;
  const ctx = c.getContext('2d')!;
  const mime = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm', 'video/mp4'].find((m) => MediaRecorder.isTypeSupported(m));
  if (!mime) throw new Error('This browser cannot record video.');
  // 포스터: 첫 장면의 글자가 다 뜬 순간
  drawFrame(ctx, scenes, Math.min(scenes[0].dur - 0.1, 0.5 + 0.7 * scenes[0].texts.length + 0.3), W, paint, stImgs);
  const poster = await new Promise<Blob>((ok, no) => c.toBlob((b) => (b ? ok(b) : no(new Error('poster'))), 'image/png'));
  const total = totalSec(scenes);
  const stream = c.captureStream(FPS);
  const rec = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 2_500_000 });
  const chunks: Blob[] = [];
  rec.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
  const done = new Promise<void>((ok) => { rec.onstop = () => ok(); });
  rec.start(250);
  const t0 = performance.now();
  await new Promise<void>((ok) => {
    const tick = () => {
      const t = (performance.now() - t0) / 1000;
      if (t >= total) { drawFrame(ctx, scenes, total - 0.01, W, paint, stImgs); ok(); return; }
      drawFrame(ctx, scenes, t, W, paint, stImgs); onProgress(t / total);
      requestAnimationFrame(tick);
    };
    tick();
  });
  await new Promise((r) => setTimeout(r, 300)); // 마지막 프레임이 인코더에 들어갈 시간
  rec.stop(); await done;
  return { video: new Blob(chunks, { type: mime.split(';')[0] }), poster, mime: mime.split(';')[0] };
}
