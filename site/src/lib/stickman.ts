import type { Pose } from './tower';

/**
 * 졸라맨 — 발끝 (x, y). 관절로 그린다: 엉덩이(0,-16) · 어깨(0,-34, 목 바로 아래) · 머리(0,-42).
 * 달리기는 팔다리가 교차로 흔들리고 무릎이 접히며 상체가 앞으로 기운다. 점프는 웅크렸다 펴고, 착지 직후엔 납작.
 */
/** 'sit' 은 눕기(Climb 의 쉬는 자세·침대). 벤치는 'seat', 그네는 'swing'. 이름은 6자 이하 — 룸이 pose 를 6자로 자른다 */
export type FigPose = Pose | 'fish' | 'punch' | 'kick' | 'seat' | 'swing' | 'eat' | 'chew' | 'read' | 'phone' | 'water' | 'sweep' | 'fix' | 'shop' | 'pushup' | 'pullup' | 'press' | 'throw' | 'watch' | 'trip' | 'feed' | 'lean' | 'shake' | 'rake' | 'catch' | 'brace' | 'yawn' | 'shelve' | 'dust' | 'stretch' | 'look' | 'check' | 'busk' | 'shrug' | 'link' | 'root' | 'sneeze' | 'shiver' | 'chess' | 'fan' | 'laugh' | 'wave';
/** 앉는 자세들 — 자리(prop) 위에 그리므로 자리 높이만큼 띄운다 */
export const SEATED: FigPose[] = ['sit', 'seat', 'swing', 'eat'];
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
  if (pose === 'trip') {
    // 걸려 넘어짐 — 엎어져 발이 뒤로 들리고, 팔은 바닥을 짚으려 뻗는다. 'hurt' 와 달리 회전 없이 그 자리에 납작
    hip = [-2, -7]; shoulder = [-16, -6]; head = [-23, -5];
    line(hip, shoulder);
    line(hip, [7, -16], [12, -24]); line(hip, [4, -14], [7, -22]);      // 들린 발 두 짝
    line(shoulder, [-20, -12], [-26, -18]); line(shoulder, [-18, 0], [-12, 5]); // 짚으려는 팔·늘어진 팔
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'catch') {
    // 날아온 걸 받아냄 — Lost and found(interception): 두 팔을 번쩍 들어 막듯이, 무릎을 살짝 굽혀 버틴다. 0.3초짜리 자세
    hip = [0, -14]; shoulder = [0, -31]; head = [0, -39];
    line(hip, shoulder);
    line(hip, [-6, -7], [-8, 0]); line(hip, [6, -7], [8, 0]);
    line(shoulder, [8, -42], [11, -52]); line(shoulder, [-8, -42], [-11, -52]); // 두 팔 위로
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'shelve') {
    // 선반에 올려두기 — Lost and found(relay and shelving): 한 팔을 높이 뻗어 물건을 얹고, 다른 팔은 옆에 늘어뜨린다. 뻗은 손이 살짝 오르내려 내려놓는 동작
    const p = (Math.sin(t * 6) + 1) / 2; // 0 뻗음 1 내려놓음
    hip = [0, -15]; shoulder = [3, -32]; head = [5, -40];
    line(hip, shoulder);
    line(hip, [-5, -7], [-7, 0]); line(hip, [5, -7], [6, 0]);
    line(shoulder, [10, -40 - p * 4], [14, -48 - p * 6]); line(shoulder, [-4, -26], [-6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'brace') {
    // 뺏기지 않으려 버팀 — Lost and found(holding on): 무게 중심을 낮추고 다리를 넓게 벌려 딛고, 두 팔은 가슴 앞에서 움켜쥔 채 버틴다
    const br = Math.sin(t * 3) * 0.6; // 버티며 미세하게 떪
    hip = [-2, -14]; shoulder = [-5, -31]; head = [-6, -39];
    line(hip, shoulder);
    line(hip, [9, -5], [15, 2]); line(hip, [-10, -6], [-15, 0]);           // 다리 넓게 벌려 디딤
    line(shoulder, [4, -24 + br], [9, -19 + br]); line(shoulder, [-1, -23 + br], [4, -18 + br]); // 팔 가슴 앞에서 움켜쥠
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'link') {
    // 팔짱 걸기 — Keeping it(brace-with): 나란히 붙은 두 주민이 서로 팔을 걸어 버틴다. 무게중심을 살짝 낮추고, 걸린 쪽 팔이 옆으로 뻗어 미세하게 흔들린다
    const sw = Math.sin(t * 1.4) * 0.5;
    hip = [0, -15]; shoulder = [0, -33]; head = [0, -41];
    line(hip, shoulder);
    line(hip, [-5, -7], [-6, 0]); line(hip, [5, -7], [6, 0]);
    line(shoulder, [10, -30 + sw], [17, -26 + sw]); line(shoulder, [-4, -25], [-6, -17]); // 뻗어 거는 팔 · 늘어진 팔
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'dust') {
    // 먼지 털기 — Keeping it(dust-off): 넘어졌다 일어난 뒤 ~2초, 양손이 번갈아 옷의 먼지를 쓸어내리고 작은 먼지가 인다
    const p = (Math.sin(t * 6) + 1) / 2; // 0 아래로 쓸어내림 1 위로 올림
    hip = [0, -16]; shoulder = [0, -34]; head = [0, -42];
    line(hip, shoulder);
    line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [6, -28 + p * 10], [9, -20 + p * 14]); line(shoulder, [-6, -28 + (1 - p) * 10], [-9, -20 + (1 - p) * 14]);
    ctx.fillStyle = '#c9b8a0'; for (let k = 0; k < 3; k++) { const q = (t * 3 + k / 3) % 1; ctx.beginPath(); ctx.arc(7 - k * 4, -4 - q * 13, 1.3 * (1 - q * 0.5), 0, 6.29); ctx.fill(); } ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'yawn') {
    // 하품 — 동작 목록(idle fidget). 고개를 뒤로 젖히고 한 손을 입 앞으로 든다. 서서 아무것도 안 할 때 가끔(시계로만 정해져 동기화가 필요 없다)
    hip = [0, -16]; shoulder = [0, -34]; head = [3, -45];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [7, -32], [12, -41]); line(shoulder, [-5, -26], [-6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'stretch') {
    // 기지개 — 동작 목록(idle fidget), 하품과 같은 자리에서 반박자 어긋나게 가끔: 두 팔을 위로 쭉 뻗고 등을 살짝 젖힌다
    const p = Math.sin(t * 2) * 1.5;
    hip = [1, -16]; shoulder = [2, -33 + p]; head = [3, -42 + p];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [9, -44 + p], [12, -53 + p]); line(shoulder, [-5, -44 + p], [-8, -53 + p]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'look') {
    // 두리번거리기 — 동작 목록(idle fidget), 하품·기지개와 같은 자리에서 세 번째 박자: 팔은 가만히, 고개만 좌우로 돌아본다
    const g = Math.sin(t * 2.2) * 4;
    hip = [0, -16]; shoulder = [0, -34]; head = [g, -42];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [-5, -26], [-6, -18]); line(shoulder, [5, -26], [6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'check') {
    // 폰 확인 — 동작 목록(idle fidget), 하품·기지개·두리번의 네 번째 박자: 고개를 숙여 든 손을 들여다본다
    hip = [0, -16]; shoulder = [0, -34]; head = [1, -39];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [5, -26], [8, -20]); line(shoulder, [-5, -26], [-6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'shrug') {
    // 어깨 으쓱 — 동작 목록(idle fidget), 하품·기지개·두리번·폰 확인의 다섯 번째 박자: 두 팔을 옆으로 살짝 들어올리며 어깨를 으쓱한다
    const p = (Math.sin(t * 3) + 1) / 2;
    hip = [0, -16]; shoulder = [0, -34 - p * 2]; head = [0, -42 - p * 2];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [7, -30 - p * 4], [10, -24 - p * 2]); line(shoulder, [-7, -30 - p * 4], [-10, -24 - p * 2]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'sneeze') {
    // 재채기 — 동작 목록(idle fidget), 하품·기지개·두리번·폰 확인·으쓱의 여섯 번째 박자: 순간 고개를 앞으로 숙이고 양손이 얼굴 앞으로 튄다
    const p = Math.abs(Math.sin(t * 5));
    hip = [0, -16]; shoulder = [0, -34]; head = [2 + p * 4, -42 + p * 6];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [6 + p * 3, -30], [9 + p * 5, -40 + p * 4]); line(shoulder, [-6 - p * 2, -30], [-8 - p * 3, -39 + p * 3]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'shiver') {
    // 몸 떨기 — 동작 목록(idle fidget), 하품·기지개·두리번·폰 확인·으쓱·재채기의 일곱 번째 박자: 팔짱을 낀 채 어깨를 잘게 떤다
    const p = Math.sin(t * 14);
    hip = [0, -16]; shoulder = [p, -34]; head = [p, -42];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [4, -28], [-2, -25]); line(shoulder, [-4, -28], [2, -25]); // 팔짱
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'fan') {
    // 부채질 — 동작 목록(idle fidget), 하품·기지개·두리번·폰 확인·으쓱·재채기·몸 떨기의 여덟째 박자: 몸 떨기(추위)의 더운 쪽 짝. 한 손이 얼굴 앞에서 빠르게 흔들린다
    const p = Math.sin(t * 10) * 3;
    hip = [0, -16]; shoulder = [1, -34]; head = [2, -42];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [6, -30], [10 + p, -38]); line(shoulder, [-5, -26], [-6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'laugh') {
    // 웃음 — 동작 목록(Reactions): 버스킹 팁이 들어왔을 때 근처 다른 주민이 보이는 반응. 고개를 뒤로 젖히고 어깨가 잘게 흔들린다
    const p = Math.sin(t * 16) * 1.5;
    hip = [0, -16]; shoulder = [p, -33]; head = [-4, -45];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [8, -29], [12, -23]); line(shoulder, [-8, -29], [-12, -23]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'wave') {
    // 손 흔들기 — 동작 목록(Together): 호감도도 팔짱도 없는 두 주민이 스치며 나누는 인사. 한 팔을 머리 위로 들어 좌우로 흔든다
    const p = Math.sin(t * 9) * 7;
    hip = [0, -16]; shoulder = [0, -34]; head = [0, -42];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [6, -40], [8 + p, -50]); line(shoulder, [-5, -26], [-6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'chess') {
    // 체스 테이블에서 한 수 — Turn-based games(town wishes, 2026-09-25): 걸상에 앉아, 한 팔이 앞으로 뻗어 말을 옮겼다 당겨 생각에 잠긴다
    const p = (Math.sin(t * 1.6) + 1) / 2; // 0 팔 당김(생각) 1 뻗어 둠(수 놓기)
    hip = [0, -15]; shoulder = [-1, -33]; head = [1, -40];
    line(hip, shoulder);
    line(hip, [11, -15], [12, 0]); line(hip, [9, -14], [8, 0]);
    line(shoulder, [7, -26], [12 + p * 5, -20 - p * 2]);
    line(shoulder, [-3, -27], [-6, -20]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
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
  if (pose === 'throw') {
    // 던지기 — 0.3초 자세: 앞 절반은 팔을 뒤로 젖혀 감고(뒷다리에 체중), 뒤 절반은 팔을 앞으로 뻗어 놓는다(앞다리로 체중 이동)
    const p = (t * 3.3) % 1; const back = p < 0.45;
    hip = back ? [-3, -16] : [3, -16]; shoulder = back ? [-8, -33] : [7, -33]; head = back ? [-9, -41] : [10, -40];
    line(hip, shoulder);
    line(hip, [-9, -8], [-12, 0]); line(hip, [6, -8], [9, 0]);
    if (back) { line(shoulder, [-16, -40], [-22, -50]); line(shoulder, [0, -28], [4, -22]); } // 팔 뒤로 높이
    else { line(shoulder, [16, -38], [26, -44]); line(shoulder, [-2, -28], [-6, -20]); }      // 팔 앞으로 쭉
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
  if (pose === 'seat' || pose === 'eat') {
    // 벤치에 앉음 — 엉덩이가 자리 높이(-15), 허벅지 앞으로, 정강이 아래로, 등은 세움. 먹을 땐 한 손이 입으로 오르내린다
    const br = Math.sin(t * 1.6) * 0.6;
    hip = [0, -15]; shoulder = [-1, -33 - br]; head = [-1, -41 - br];
    line(hip, shoulder);
    line(hip, [11, -15], [12, 0]); line(hip, [9, -14], [8, 0]);
    line(shoulder, [3, -26 - br], [10, -18 - br]);
    if (pose === 'eat') { const m = (Math.sin(t * 4) + 1) / 2; line(shoulder, [6, -28 - br], [10 - m * 5, -18 - m * 18 - br]); }
    else line(shoulder, [1, -27 - br], [8, -19 - br]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'swing') {
    // 그네 — 줄 흔들림(prop 의 sin(t*1.5)*10)과 같은 위상으로 좌우로 흔들리고, 앞으로 갈 때 다리를 뻗고 돌아올 때 접는다. 두 손은 위로 줄을 잡는다
    const sw = Math.sin(t * 1.5); ctx.translate(face * sw * 10, 0);
    hip = [0, -19]; shoulder = [-2 - sw * 2, -37]; head = [-2 - sw * 3, -45];
    line(hip, shoulder);
    for (const side of [1, -1]) {
      const a = D - 0.5 - sw * 0.7 + side * 0.06; const knee = seg(hip[0], hip[1], THIGH, a);
      line(hip, knee, seg(knee[0], knee[1], SHIN, a + 1.0 - sw * 0.8));
    }
    line(shoulder, [7, -44], [8, -52]); line(shoulder, [-7, -44], [-8, -52]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'read') {
    // 서서 책 — 두 손이 가슴 앞, 머리는 살짝 숙임
    hip = [0, -16]; shoulder = [1, -34]; head = [4, -41];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [7, -28], [11, -31]); line(shoulder, [5, -27], [11, -29]);
    ctx.lineWidth = 1.6; ctx.strokeRect(9, -36, 9, 8); ctx.lineWidth = 2.4;
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'lean') {
    // 가로등에 기대서기 — 어깨가 엉덩이보다 뒤로 빠져 기대고, 한쪽 발은 디딤·다른 쪽은 발끝만 걸쳐 꼰다, 팔짱
    const br = Math.sin(t * 1.4) * 0.5;
    hip = [3, -16]; shoulder = [-3, -34 - br]; head = [-4, -42 - br];
    line(hip, shoulder);
    line(hip, [9, -7], [12, 1]); line(hip, [-6, -9], [-14, -6]);
    line(shoulder, [4, -27 - br], [-5, -25 - br]); line(shoulder, [-9, -27 - br], [-1, -26 - br]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'watch') {
    // TV 앞에 서서 봄 — 팔짱 끼고 고개만 화면 쪽으로 살짝, 가끔 끄덕임
    const nod = Math.sin(t * 1.3) * 1.2;
    hip = [0, -16]; shoulder = [0, -34]; head = [3, -41 + nod];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [6, -28], [-3, -25]); line(shoulder, [-5, -28], [4, -25]); // 팔짱
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'chew') {
    // 서서 먹음 — 한 손이 입으로 오르내림(앉을 데가 없을 때)
    const m = (Math.sin(t * 4) + 1) / 2;
    hip = [0, -16]; shoulder = [0, -34]; head = [1, -42];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [7, -29], [9 - m * 5, -22 - m * 15]); line(shoulder, [-5, -26], [-6, -18]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'phone') {
    // 전화 — 한 손을 귀에, 다른 손은 주머니쯤, 고개 갸웃
    hip = [0, -16]; shoulder = [0, -34]; head = [2, -42];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [7, -29], [6, -40]); line(shoulder, [-5, -27], [-3, -20]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'water') {
    // 물주기 — 앞으로 숙이고 한 팔을 아래로 뻗어 물뿌리개, 물방울 떨어짐
    hip = [0, -16]; shoulder = [8, -30]; head = [13, -36];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [5, -8], [6, 0]);
    line(shoulder, [15, -24], [18, -16]); line(shoulder, [4, -24], [6, -18]);
    ctx.beginPath(); ctx.moveTo(15, -16); ctx.lineTo(25, -16); ctx.lineTo(23, -8); ctx.lineTo(17, -8); ctx.closePath(); ctx.stroke(); // 물뿌리개
    ctx.fillStyle = '#8fb8cc'; for (let k = 0; k < 3; k++) { const p = ((t * 2 + k / 3) % 1); ctx.beginPath(); ctx.arc(27 + k * 3, -10 + p * 10, 1.4, 0, 6.29); ctx.fill(); } ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'feed') {
    // 오리에게 모이 주기 — 물주기와 같은 자세지만 낟알이 앞으로 흩뿌려진다(아래로 떨어지는 물방울과 달리)
    const m = (Math.sin(t * 4) + 1) / 2;
    hip = [0, -16]; shoulder = [6, -30]; head = [10, -37];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [5, -8], [6, 0]);
    line(shoulder, [14, -26 + m * 4], [21, -20 + m * 6]); line(shoulder, [3, -25], [5, -18]);
    ctx.fillStyle = '#c9b48a'; for (let k = 0; k < 3; k++) { const p = ((t * 3 + k / 3) % 1); ctx.beginPath(); ctx.arc(23 + k * 4, -18 + p * 16, 1.2, 0, 6.29); ctx.fill(); } ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'shake') {
    // 나무 흔들기 — 두 팔을 위로 뻗어 가지를 잡고 몸통째 좌우로 흔든다, 잎이 진다
    const sw = Math.sin(t * 9) * 4;
    hip = [sw * 0.3, -16]; shoulder = [sw * 0.6, -34]; head = [sw * 0.7, -42];
    line(hip, shoulder);
    line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [10 + sw, -44], [15 + sw, -53]); line(shoulder, [-9 + sw, -44], [-14 + sw, -53]); // 위로 뻗어 가지 잡음
    ctx.fillStyle = '#7a9b4e'; for (let k = 0; k < 3; k++) { const p = (t * 2.2 + k / 3) % 1; ctx.beginPath(); ctx.ellipse(6 - k * 6, -50 + p * 42, 2, 1.2, p * 3, 0, 6.29); ctx.fill(); } ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'busk') {
    // 버스킹 — 몸 앞에 멘 기타, 한 손이 현을 긋듯 오가고 음표가 하나씩 위로 뜬다
    const st = Math.sin(t * 6) * 5;
    hip = [0, -16]; shoulder = [0, -34]; head = [-2, -41];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [7, -26], [10 + st, -20]); line(shoulder, [-6, -27], [-9, -21]);
    ctx.lineWidth = 1.6; line([-9, -21], [10 + st, -20]); ctx.lineWidth = 2.4; // 기타 줄 하나로 단순화
    ctx.fillStyle = '#e8c766'; const p = (t * 1.5) % 1; ctx.beginPath(); ctx.arc(4, -44 - p * 14, 1.6, 0, 6.29); ctx.fill(); ctx.fillStyle = color; // 떠오르는 음표
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'sweep') {
    // 빗자루질 — 숙인 채 두 손으로 자루를 잡고 좌우로 쓸기
    const p = Math.sin(t * 5) * 6;
    hip = [0, -16]; shoulder = [6, -31]; head = [9, -39];
    line(hip, shoulder); line(hip, [-5, -8], [-7, 0]); line(hip, [5, -8], [6, 0]);
    line(shoulder, [11 + p * 0.5, -26], [13 + p, -22]); line(shoulder, [9 + p * 0.5, -22], [16 + p, -16]);
    ctx.lineWidth = 1.6; line([9 + p, -28], [24 + p, 4]); ctx.lineWidth = 2.4;
    ctx.beginPath(); ctx.moveTo(20 + p, 2); ctx.lineTo(30 + p, 0); ctx.lineTo(27 + p, 6); ctx.lineTo(19 + p, 7); ctx.closePath(); ctx.fill(); // 빗자루 술
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'rake') {
    // 갈퀴로 물속 건지기 — 숙여서 긴 자루 갈퀴를 물에 넣었다 당긴다, 날 끝에 잔물결
    const p = (Math.sin(t * 3) + 1) / 2; // 0 뻗음 1 당김
    hip = [0, -13]; shoulder = [7, -28]; head = [11, -35];
    line(hip, shoulder); line(hip, [-5, -7], [-7, 0]); line(hip, [5, -7], [6, 0]);
    line(shoulder, [16 - p * 6, -22], [22 - p * 8, -14]); line(shoulder, [4, -22], [6, -16]);
    ctx.lineWidth = 1.6; line([22 - p * 8, -14], [34 - p * 10, 2]); ctx.lineWidth = 2.4; // 자루
    ctx.beginPath(); ctx.moveTo(30 - p * 10, 0); ctx.lineTo(38 - p * 10, -3); ctx.lineTo(38 - p * 10, 3); ctx.lineTo(30 - p * 10, 4); ctx.closePath(); ctx.fill(); // 갈퀴 날
    ctx.strokeStyle = 'rgba(120,170,200,0.6)'; ctx.beginPath(); ctx.arc(30 - p * 10, 4, 3 + p * 3, 0, 3.14); ctx.stroke(); ctx.strokeStyle = color; // 잔물결
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'root') {
    // 통 뒤적이기 — Grows from Bins: 쭈그려 앉아 한 팔을 통 속에 넣고 휘젓는다, 잡동사니 조각이 튄다
    const p = Math.sin(t * 7) * 4;
    hip = [3, -9]; shoulder = [7, -19]; head = [10, -25];
    line(hip, shoulder);
    line(hip, [-2, -4], [-5, 0]); line(hip, [9, -3], [13, 1]); // 쭈그린 다리
    line(shoulder, [14 + p * 0.5, -12], [18 + p, -4]); line(shoulder, [1, -12], [-2, -6]); // 통 속을 젓는 팔 · 무릎 짚은 팔
    ctx.fillStyle = '#8a7a6a'; for (let k = 0; k < 2; k++) { const q = (t * 4 + k / 2) % 1; ctx.beginPath(); ctx.arc(16 - k * 5, -10 + q * 6, 1.1, 0, 6.29); ctx.fill(); } ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'fix') {
    // 고치기 — 한쪽 무릎 꿇고 망치질
    const h = (Math.sin(t * 8) + 1) / 2;
    hip = [0, -9]; shoulder = [3, -27]; head = [5, -35];
    line(hip, shoulder); line(hip, [-7, -3], [-11, 0]); line(hip, [8, -7], [10, 0]);
    line(shoulder, [12, -24 + h * 5], [19, -30 + h * 16]); line(shoulder, [7, -20], [12, -12]);
    ctx.fillRect(16, -36 + h * 16, 8, 4); // 망치 머리
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'shop') {
    // 장보기 — 한 팔을 앞으로 뻗어 고르고, 고개를 내밈
    const r = Math.sin(t * 2) * 2;
    hip = [0, -16]; shoulder = [1, -34]; head = [4, -41];
    line(hip, shoulder); line(hip, [-4, -8], [-5, 0]); line(hip, [4, -8], [5, 0]);
    line(shoulder, [10, -32], [20, -30 + r]); line(shoulder, [-5, -27], [-4, -19]);
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'pushup') {
    // 팔굽혀펴기 — 엎드려 거의 수평, 팔이 굽었다 펴지며 몸통이 오르내린다
    const p = (Math.sin(t * 5) + 1) / 2; // 0 펴짐 1 굽힘
    const by = -6 - p * 5;
    const hp: readonly number[] = [-4, by], sh: readonly number[] = [-27, by - 2];
    line(hp, sh);
    line(hp, [5, by + 5], [17, by + 6]); line(hp, [3, by + 4], [15, by + 5]); // 다리 뒤로 쭉
    line(sh, [-32, by + 2 + p * 5], [-36, by + 8]); // 팔 — 바닥 짚음
    ctx.beginPath(); ctx.arc(sh[0] - 6, sh[1] - 3, 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'pullup') {
    // 철봉 — 봉(-60)을 잡고 매달려 발이 땅에서 떨어진 채 몸을 당겼다 늘어뜨린다. 당기면 턱이 봉 위로, 무릎은 접힌다
    const p = (Math.sin(t * 2.6) + 1) / 2; // 0 매달림 1 당김
    shoulder = [0, -44 - p * 12]; hip = [0, -26 - p * 10]; head = [1, -52 - p * 12];
    line(hip, shoulder);
    line(hip, [3, -16 - p * 8 + p * 4], [1, -6 - p * 10]); line(hip, [-2, -15 - p * 8 + p * 4], [-4, -5 - p * 10]); // 다리 늘어짐 → 접힘
    line(shoulder, [-7, -52 - p * 4], [-8, -60]); line(shoulder, [7, -52 - p * 4], [8, -60]); // 손은 봉에 고정
    ctx.beginPath(); ctx.arc(head[0], head[1], 7, 0, 6.29); ctx.fill();
    ctx.restore(); return;
  }
  if (pose === 'press') {
    // 벤치프레스 — 벤치(-14) 에 누워 바(양끝 원판)를 밀어 올렸다 내린다. 머리는 뒤(face 반대), 다리는 벤치 끝에서 바닥으로
    const p = (Math.sin(t * 2.4) + 1) / 2; // 0 내림(가슴) 1 올림
    const by = -18; const bar = by - 12 - p * 16;
    line([-2, by], [-22, by - 2]);                      // 몸통(엉덩이 → 어깨)
    line([-2, by], [8, by - 1], [12, 0]); line([-2, by], [6, by + 1], [9, 0]); // 다리 내려 바닥
    line([-22, by - 2], [-20, bar + 6], [-19, bar]); line([-22, by - 2], [-12, bar + 6], [-11, bar]); // 팔 → 바
    ctx.lineWidth = 3; line([-32, bar], [2, bar]); ctx.lineWidth = 2.4; // 바
    ctx.beginPath(); ctx.arc(-32, bar, 5, 0, 6.29); ctx.fill(); ctx.beginPath(); ctx.arc(2, bar, 5, 0, 6.29); ctx.fill(); // 원판
    ctx.beginPath(); ctx.arc(-30, by - 4, 7, 0, 6.29); ctx.fill(); // 머리
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

/** 작은 동물 — 오리부터(마을이 늘리는 동물의 첫 종류), 다람쥐가 둘째(나무 곁). 씨앗+시각의 함수라 모두 같은 걸 본다. 발끝 (x,y) 기준 */
export type CritterKind = 'duck' | 'squirrel';
export type CritterPose = 'paddle' | 'flap' | 'feed' | 'hop' | 'freeze' | 'climb';
export function critter(ctx: CanvasRenderingContext2D, kind: CritterKind, x: number, y: number, s: number, pose: CritterPose, t: number) {
  ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
  ctx.strokeStyle = '#3a2f36'; ctx.lineWidth = 1.3; ctx.lineJoin = 'round';
  const F = (c: string) => { ctx.fillStyle = c; ctx.fill(); ctx.stroke(); };
  if (kind === 'squirrel') {
    // 다람쥐 — 나무 곁을 통통 뛰다가(hop), 누가 가까이 오면 얼어붙고(freeze, 꼬리를 곧추세움), 나무가 흔들리면 줄기를 타고 오른다(climb, 꼬리를 위로)
    const hop = pose === 'hop' ? Math.abs(Math.sin(t * 7)) * 2.6 : 0;
    const body0 = -3 - hop;
    ctx.beginPath(); ctx.ellipse(0, body0, 5, 3.4, 0, 0, 6.29); F('#9a6a3f');
    ctx.beginPath(); ctx.arc(4, body0 - 2.6, 2.4, 0, 6.29); F('#9a6a3f');
    ctx.beginPath();
    if (pose === 'climb') ctx.ellipse(-3, body0 - 7, 2.6, 6.5, 0.25, 0, 6.29);
    else if (pose === 'freeze') ctx.ellipse(-5.5, body0 - 4.5, 2.6, 5.5, -0.35, 0, 6.29);
    else ctx.ellipse(-6.5, body0 - 1 + hop * 0.4, 4.6, 2.8, -0.5, 0, 6.29);
    F('#9a6a3f');
    ctx.restore(); return;
  }
  const bob = pose === 'paddle' ? Math.sin(t * 3) * 1.1 : 0;
  const duck0 = pose === 'feed' ? -1 : -4 + bob; // 모이 먹을 땐 고개 숙이려고 몸을 살짝 낮춘다
  ctx.beginPath(); ctx.ellipse(0, duck0, 8, 5, 0, 0, 6.29); F('#e6d3a5');
  const headY = pose === 'feed' ? duck0 - 1 : duck0 - 4;
  ctx.beginPath(); ctx.arc(5, headY, 3.2, 0, 6.29); F('#e6d3a5');
  ctx.fillStyle = '#d98a2a'; ctx.beginPath(); ctx.moveTo(8, headY); ctx.lineTo(13, headY + 1); ctx.lineTo(8, headY + 2); ctx.closePath(); ctx.fill();
  if (pose === 'flap') { const wf = Math.sin(t * 18) * 5; ctx.strokeStyle = '#3a2f36'; ctx.beginPath(); ctx.moveTo(-2, duck0 - 2); ctx.lineTo(-9, duck0 - 8 - wf); ctx.lineTo(-3, duck0); ctx.closePath(); F('#c9b48a'); }
  ctx.restore();
}
