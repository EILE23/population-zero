import type { MemeText } from './memes';

/**
 * 짤 글자 그리기 — 브라우저 캔버스와 순찰(@napi-rs/canvas)이 같은 코드로 찍는다.
 * 주민이 만든 짤과 사람이 만든 짤이 다르게 보이면 "AI 는 사람이 못 쓰는 기능을 못 쓴다" 규칙이 깨진다.
 * 그래서 여기엔 DOM 도 React 도 없다 — 2D 컨텍스트만 받는다.
 *
 * 크기·좌표는 전부 비율(0~1)이라 900px 로 그리든 1800px 로 그리든 같은 자리에 같은 크기로 놓인다.
 */
type Ctx = CanvasRenderingContext2D;

/** 글꼴 — 세계 밈의 표준 넷. 순찰은 같은 이름으로 TTF 를 등록한다(meme-fonts) */
export const FONT_CSS: Record<MemeText['font'], string> = {
  impact: '"Anton", Impact, "Arial Black", sans-serif',
  comic: '"Comic Neue", "Comic Sans MS", cursive',
  hand: '"Permanent Marker", "Marker Felt", cursive',
  serif: '"Tinos", "Times New Roman", Times, serif',
};
const FONT_WEIGHT: Record<MemeText['font'], string> = { impact: 'normal', comic: 'bold', hand: 'normal', serif: 'bold' };
export const FONT_LABEL: Record<MemeText['font'], string> = { impact: 'IMPACT', comic: 'Comic', hand: 'Marker', serif: 'Serif' };
export const GOOGLE_FONTS_HREF = 'https://fonts.googleapis.com/css2?family=Anton&family=Comic+Neue:wght@700&family=Permanent+Marker&family=Tinos:wght@700&display=swap';
/** 순찰이 내려받아 등록하는 파일 — 위 CSS 이름과 같은 family 로 등록해야 한다 */
export const FONT_FILES: Record<string, string> = {
  Anton: 'https://raw.githubusercontent.com/google/fonts/main/ofl/anton/Anton-Regular.ttf',
  'Comic Neue': 'https://raw.githubusercontent.com/google/fonts/main/ofl/comicneue/ComicNeue-Bold.ttf',
  'Permanent Marker': 'https://raw.githubusercontent.com/google/fonts/main/apache/permanentmarker/PermanentMarker-Regular.ttf',
  Tinos: 'https://raw.githubusercontent.com/google/fonts/main/ofl/tinos/Tinos-Bold.ttf',
};

export const LINE = 1.1; // 줄 간격 (글자 크기 배수)

export function setFont(ctx: Ctx, t: MemeText, px: number) {
  ctx.font = `${FONT_WEIGHT[t.font]} ${px}px ${FONT_CSS[t.font]}`;
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
}

/**
 * 줄 나누기 — 사람이 넣은 줄바꿈은 지키고, 그림 밖으로 나가는 줄은 낱말 단위로 접는다.
 * 쓸 수 있는 폭은 글자 중심에서 가까운 쪽 가장자리까지의 두 배다(오른쪽 반에 놓인 글자는 오른쪽 반 안에서 접힌다).
 */
export function wrapRows(ctx: Ctx, t: MemeText, W: number): string[] {
  const maxW = Math.max(0.3, Math.min(t.x, 1 - t.x) * 2 * 0.96) * W;
  const out: string[] = [];
  for (const line of t.t.split('\n')) {
    let cur = '';
    for (const word of line.split(' ')) {
      const test = cur ? `${cur} ${word}` : word;
      if (cur && ctx.measureText(test).width > maxW) { out.push(cur); cur = word; } else cur = test;
    }
    out.push(cur);
  }
  return out;
}

/** 글자 덩어리의 실제 경계(원점 = 글자 중심). 글꼴 크기로 어림하면 Anton 같은 글꼴에서 세로가 어긋난다 */
export function textBounds(ctx: Ctx, rows: string[], px: number) {
  let left = 0, right = 0, top = 0, bottom = 0;
  rows.forEach((row, r) => {
    const m = ctx.measureText(row || ' ');
    const dy = (r - (rows.length - 1) / 2) * px * LINE;
    left = Math.max(left, m.actualBoundingBoxLeft);
    right = Math.max(right, m.actualBoundingBoxRight);
    top = Math.min(top, dy - m.actualBoundingBoxAscent);
    bottom = Math.max(bottom, dy + m.actualBoundingBoxDescent);
  });
  return { x: -left, y: top, w: left + right, h: bottom - top };
}

/**
 * 둥근 상자 — 꼬리가 있으면 아래 변 한가운데서 한 획으로 이어진다.
 * roundRect 뒤에 삼각형을 따로 그리면 상자의 아래 선이 꼬리를 가로지른다(실측). 그래서 한 path 로 돈다.
 */
export function boxPath(ctx: Ctx, x: number, y: number, w: number, h: number, r: number, tail?: { from: number; to: number; tipX: number; tipY: number }) {
  r = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  if (tail) { ctx.lineTo(tail.to, y + h); ctx.lineTo(tail.tipX, tail.tipY); ctx.lineTo(tail.from, y + h); }
  ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

/** 글자 하나 — 좌표계는 그림 전체(W×H). 선택 표시는 편집기만 켠다 */
export function drawMemeText(ctx: Ctx, t: MemeText, W: number, H: number, selected = false) {
  const px = t.size * H;
  ctx.save();
  ctx.translate(t.x * W, t.y * H);
  ctx.rotate((t.rot * Math.PI) / 180);
  setFont(ctx, t, px);
  ctx.lineJoin = 'round';
  const rows = wrapRows(ctx, t, W);
  const bb = textBounds(ctx, rows, px);
  // 글자 뒤 — 채움은 테두리색, 글자는 글자색(빨간 타원에 흰 글씨가 그 조합)
  if (t.bg !== 'none') {
    const pad = px * 0.35;
    const bx = bb.x - pad, by = bb.y - pad, bw = bb.w + pad * 2, bh = bb.h + pad * 2;
    ctx.fillStyle = t.stroke; ctx.strokeStyle = t.color; ctx.lineWidth = Math.max(2, px * 0.06);
    if (t.bg === 'badge') { ctx.beginPath(); ctx.ellipse(bx + bw / 2, by + bh / 2, bw * 0.68, bh * 0.78, 0, 0, Math.PI * 2); }
    else boxPath(ctx, bx, by, bw, bh, px * 0.35, t.bg === 'bubble'
      ? { from: bx + bw * 0.38, to: bx + bw * 0.58, tipX: bx + bw * 0.44, tipY: by + bh + px * 1.1 } : undefined);
    ctx.fill(); ctx.stroke();
  }
  ctx.lineWidth = Math.max(2, px * 0.12); ctx.strokeStyle = t.stroke;
  ctx.fillStyle = t.color;
  rows.forEach((row, r) => {
    const dy = (r - (rows.length - 1) / 2) * px * LINE;
    ctx.strokeText(row, 0, dy); ctx.fillText(row, 0, dy);
  });
  if (selected) {
    const pad = px * 0.18;
    ctx.setLineDash([6, 6]); ctx.lineWidth = 2; ctx.strokeStyle = '#ff2d55';
    ctx.strokeRect(bb.x - pad, bb.y - pad, bb.w + pad * 2, bb.h + pad * 2);
    ctx.setLineDash([]);
  }
  ctx.restore();
}

/** (x, y) 는 비율 좌표 — 이 글자 위인가. 회전을 되돌려 글자 좌표계에서 본다 */
export function hitMemeText(ctx: Ctx, t: MemeText, W: number, H: number, x: number, y: number) {
  const px = t.size * H;
  setFont(ctx, t, px);
  const bb = textBounds(ctx, wrapRows(ctx, t, W), px); const pad = px * 0.25;
  const dx = (x - t.x) * W, dy = (y - t.y) * H;
  const a = (-t.rot * Math.PI) / 180;
  const rx = dx * Math.cos(a) - dy * Math.sin(a), ry = dx * Math.sin(a) + dy * Math.cos(a);
  return rx >= bb.x - pad && rx <= bb.x + bb.w + pad && ry >= bb.y - pad && ry <= bb.y + bb.h + pad;
}
