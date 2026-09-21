import type { Pose } from './tower';

/**
 * 졸라맨 — 발끝 (x, y). 관절로 그린다: 엉덩이(0,-16) · 어깨(0,-34, 목 바로 아래) · 머리(0,-42).
 * 달리기는 팔다리가 교차로 흔들리고 무릎이 접히며 상체가 앞으로 기운다. 점프는 웅크렸다 펴고, 착지 직후엔 납작.
 */
export type FigPose = Pose | 'fish' | 'punch' | 'kick';
export function figure(ctx: CanvasRenderingContext2D, x: number, y: number, s: number, pose: FigPose, face: 1 | -1, color: string, t: number, arms: boolean) {
  ctx.save(); ctx.translate(x, y); ctx.scale(face * s, s);
  ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = 2.4; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  const seg = (x0: number, y0: number, len: number, ang: number) => [x0 + Math.cos(ang) * len, y0 + Math.sin(ang) * len] as const; // ang: 0 = 오른쪽, π/2 = 아래
  const line = (a: readonly number[], b: readonly number[], c?: readonly number[]) => { ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); if (c) ctx.lineTo(c[0], c[1]); ctx.stroke(); };
  const D = Math.PI / 2;
  const ph = t * 13; // 걸음 위상
  let hip: readonly number[] = [0, -16], shoulder: readonly number[] = [0, -34], head: readonly number[] = [0, -42], lean = 0;
  const THIGH = 11, SHIN = 10, UPPER = 9, FORE = 9;
  if (pose === 'fish') {
    // 물가에 앉아 낚싯대를 앞으로 — 무릎 세우고, 한 손은 대, 한 손은 무릎. 대는 (18,-30) 에서 앞으로 46px
    const br = Math.sin(t * 1.6) * 0.6;
    line([0, -12], [-3, -30 - br]);                       // 몸통
    line([0, -12], [9, -18], [10, 0]); line([0, -12], [11, -16], [13, 0]); // 다리
    line([-3, -30 - br], [6, -24 - br], [9, -18]);        // 팔 하나 무릎
    line([-3, -30 - br], [8, -30 - br], [16, -32 - br]);  // 팔 하나 대 잡음
    ctx.lineWidth = 1.6; line([16, -32 - br], [58, -52 - br]); ctx.lineWidth = 2.4; // 낚싯대
    ctx.beginPath(); ctx.arc(-4, -38 - br, 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'punch') {
    // 앞으로 내지르는 주먹 — 상체가 앞으로, 뒷팔은 당김, 다리는 벌림
    hip = [0, -16]; shoulder = [4, -34]; head = [5, -42];
    line(hip, shoulder);
    line(hip, [-7, -8], [-9, 0]); line(hip, [8, -8], [10, 0]);
    line(shoulder, [12, -34], [24, -35]);          // 뻗은 팔
    line(shoulder, [-4, -28], [-8, -22]);          // 당긴 팔
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'kick') {
    // 옆차기 — 디딤발 하나, 찬 발이 앞으로 쭉, 몸은 뒤로 기움
    hip = [0, -16]; shoulder = [-5, -34]; head = [-6, -42];
    line(hip, shoulder);
    line(hip, [-4, -8], [-6, 0]);                  // 디딤발
    line(hip, [10, -18], [24, -20]);               // 찬 발
    line(shoulder, [-12, -30], [-16, -22]); line(shoulder, [3, -30], [8, -26]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'sit') {
    // 누워서 쉼 — 머리는 뒤(face 반대쪽), 다리는 앞으로 쭉, 한 팔은 머리 뒤에, 다른 팔은 배 위에. 발끝이 (0,0) 이라 발판 위에 눕는다
    const br = Math.sin(t * 1.6) * 0.8; // 숨
    line([-2, -4], [-24, -5 - br]);                   // 몸통 (엉덩이 → 어깨)
    line([-2, -4], [8, -5], [18, -3]);                // 다리 하나 쭉
    line([-2, -4], [6, -9], [14, -3]);                // 다리 하나 무릎 세움
    line([-24, -5 - br], [-18, -11 - br], [-30, -12 - br]); // 팔 머리 뒤
    line([-24, -5 - br], [-14, -7 - br]);             // 팔 배 위
    ctx.beginPath(); ctx.arc(-33, -9 - br, 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'run') {
    const sw = Math.sin(ph), cw = Math.cos(ph);
    const bob = Math.abs(cw) * 2.6;
    lean = 0.32;
    hip = [0, -16 - bob]; shoulder = seg(hip[0], hip[1], 18, -D + lean); head = seg(shoulder[0], shoulder[1], 8, -D + lean);
    line(hip, shoulder);
    // 다리: 허벅지 ±40°, 뒤로 간 다리는 무릎이 접힌다
    for (const side of [1, -1]) {
      const a = D + side * sw * 0.9;
      const knee = seg(hip[0], hip[1], THIGH, a);
      const bend = side * sw < 0 ? 1.4 : 0.2; // 뒤로 갈 때 접힘
      const foot = seg(knee[0], knee[1], SHIN, a + bend);
      line(hip, knee, foot);
    }
    // 팔: 다리와 반대 위상, 팔꿈치 90°
    for (const side of [1, -1]) {
      const a = D - side * sw * 1.05 + lean;
      const elbow = seg(shoulder[0], shoulder[1], UPPER, a);
      const hand = seg(elbow[0], elbow[1], FORE, a - 1.7);
      line(shoulder, elbow, hand);
    }
  } else if (pose === 'charge') {
    // 웅크리고 힘 모으는 중
    hip = [0, -11]; shoulder = [3, -27]; head = [4, -35];
    line(hip, shoulder);
    line(hip, [7, -6], [5, 0]); line(hip, [-5, -6], [-6, 0]);
    line(shoulder, [-2, -20], [-6, -12]); line(shoulder, [8, -21], [10, -13]);
  } else if (pose === 'jump') {
    // 웅크렸다 펴는 중: 무릎 당김, 팔 위로
    hip = [0, -18]; shoulder = [1, -36]; head = [2, -44];
    line(hip, shoulder);
    line(hip, [7, -12], [4, -4]); line(hip, [-2, -10], [-6, -2]);
    line(shoulder, [7, -44], [10, -52]); line(shoulder, [-6, -42], [-8, -50]);
  } else if (pose === 'fall' || pose === 'hurt') {
    const fl = Math.sin(t * 22) * 0.5;
    hip = [0, -16]; shoulder = [-1, -34]; head = [-2, -42];
    line(hip, shoulder);
    line(hip, [8, -6], [10, 2]); line(hip, [-9, -8], [-12, 0]);
    line(shoulder, seg(shoulder[0], shoulder[1], 8, -D - 0.6 + fl), seg(shoulder[0], shoulder[1], 15, -D - 0.9 + fl));
    line(shoulder, seg(shoulder[0], shoulder[1], 8, -D + 0.9 - fl), seg(shoulder[0], shoulder[1], 15, -D + 1.3 - fl));
  } else {
    // 서 있음: 숨 쉬듯 미세하게, 팔짱(arms) 이면 앞으로
    const br = Math.sin(t * 2) * 0.6;
    hip = [0, -16]; shoulder = [0, -34 - br]; head = [0, -42 - br];
    line(hip, shoulder);
    line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    if (arms) { line(shoulder, [7, -28], [-3, -25]); line(shoulder, [-6, -28], [4, -26]); }
    else { line(shoulder, [-5, -26], [-6, -18]); line(shoulder, [5, -26], [6, -18]); }
  }
  ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
  if (pose === 'hurt') { ctx.beginPath(); ctx.arc(head[0], head[1], 12, 0, 6.29); ctx.strokeStyle = '#ff2d55'; ctx.stroke(); }
  ctx.restore();
}
