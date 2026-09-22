'use client';
import { useEffect, useRef } from 'react';
import Link from 'next/link';
import { figure, figureColor, hash, rng, type FigPose } from '@/features/games/engine';

/**
 * 놀이터 카드 — 정지 그림 대신 작은 무대가 실제로 돈다(같은 엔진의 졸라맨). 보일 때만 그린다(IntersectionObserver).
 *   climb  탑 발판 몇 개, 한 사람이 충전 점프로 올라가고 주민 하나가 발판에 누워 있다
 *   square 광장 바닥, 분수·벤치, 주민 둘이 걷고 읽고, 사람이 달려든다
 *   game   사람이 만든 게임 — 이름 씨앗 색의 졸라맨이 자세를 바꿔 가며 서 있다
 */
export type Preview = 'climb' | 'square' | 'game';
const W = 320, H = 180;

export function GameCard({ href, title, blurb, by, preview, seed = 0 }: { href: string; title: string; blurb: string; by: React.ReactNode; preview: Preview; seed?: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = canvas.current!; const ctx = c.getContext('2d')!;
    const dpr = Math.min(2, devicePixelRatio || 1); c.width = W * dpr; c.height = H * dpr;
    let raf = 0, on = false; const t0 = performance.now();
    const draw = () => { if (!on) return; raf = requestAnimationFrame(draw); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); scene(ctx, preview, (performance.now() - t0) / 1000, seed); };
    const io = new IntersectionObserver((es) => { const vis = es.some((e) => e.isIntersecting); if (vis && !on) { on = true; draw(); } else if (!vis) { on = false; cancelAnimationFrame(raf); } }, { threshold: 0.2 });
    io.observe(c);
    return () => { on = false; cancelAnimationFrame(raf); io.disconnect(); };
  }, [preview, seed]);
  return (
    <li className="overflow-hidden rounded-xl border border-hairline bg-paper">
      <Link href={href} className="group block">
        <canvas ref={canvas} width={W} height={H} className="block aspect-video w-full bg-[#eef0f2] transition-transform duration-300 group-hover:scale-[1.02]" aria-hidden />
        <div className="p-4">
          <span className="font-display text-[20px] font-bold tracking-tight group-hover:underline">{title}</span>
          <p className="mt-1 text-[13px] text-ink-mid">{blurb}</p>
          <p className="mt-2 font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">by {by}</p>
        </div>
      </Link>
    </li>
  );
}

function scene(ctx: CanvasRenderingContext2D, kind: Preview, t: number, seed: number) {
  ctx.clearRect(0, 0, W, H);
  const INK = '#3a2f36';
  if (kind === 'climb') {
    ctx.fillStyle = '#e9ecef'; ctx.fillRect(0, 0, W, H);
    // 발판 — 탑 한 구간. 카메라는 사람을 따라 아주 살짝 위로
    const plats = [[20, 160, 90], [150, 125, 70], [70, 85, 60], [220, 70, 80], [140, 30, 60]] as const;
    const scroll = (Math.sin(t * 0.5) + 1) * 6;
    ctx.fillStyle = '#5b4f56';
    for (const [x, y, w] of plats) ctx.fillRect(x, y + scroll, w, 5);
    // 사람: 발판 1 → 2 → 3 을 돌며 충전→점프→착지
    const cyc = 2.6, u = (t % cyc) / cyc; const hops = [[65, 160], [185, 125], [100, 85]] as const;
    const i = Math.floor(t / cyc) % 3, a = hops[i], b = hops[(i + 1) % 3];
    let pose: FigPose = 'stand', x = a[0], y = a[1];
    if (u < 0.35) pose = 'charge';
    else if (u < 0.8) { const k = (u - 0.35) / 0.45; x = a[0] + (b[0] - a[0]) * k; y = a[1] + (b[1] - a[1]) * k - Math.sin(k * Math.PI) * 70; pose = k < 0.5 ? 'jump' : 'fall'; }
    else { x = b[0]; y = b[1]; pose = 'stand'; }
    figure(ctx, x, y + scroll, 1.05, pose, b[0] >= a[0] ? 1 : -1, figureColor(seed || 7), t, false);
    figure(ctx, 255, 70 + scroll, 0.95, 'sit', -1, INK, t, false); // 쉬는 주민
    return;
  }
  if (kind === 'square') {
    ctx.fillStyle = '#eef0f2'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#dcd8db'; for (let k = 0; k < 6; k++) ctx.fillRect(10 + k * 56, 40 + (k % 2) * 8, 34, 48 - (k % 2) * 8);
    const g = ctx.createLinearGradient(0, 88, 0, H); g.addColorStop(0, '#cfc7c2'); g.addColorStop(1, '#e6e0da'); ctx.fillStyle = g; ctx.fillRect(0, 88, W, H - 88);
    // 분수·벤치
    ctx.strokeStyle = INK; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.ellipse(160, 128, 40, 12, 0, 0, 6.29); ctx.fillStyle = '#b9b1b6'; ctx.fill(); ctx.stroke();
    ctx.beginPath(); ctx.ellipse(160, 126, 32, 8, 0, 0, 6.29); ctx.fillStyle = '#c9dde6'; ctx.fill(); ctx.stroke();
    ctx.fillStyle = '#b9b1b6'; ctx.fillRect(157, 100, 6, 26); ctx.strokeStyle = '#8fb8cc'; for (let k = 0; k < 4; k++) { ctx.beginPath(); ctx.moveTo(160, 100); ctx.quadraticCurveTo(160 + (k - 1.5) * 12, 84 + Math.sin(t * 3 + k) * 3, 160 + (k - 1.5) * 16, 122); ctx.stroke(); }
    ctx.fillStyle = '#8b6b4a'; ctx.fillRect(40, 146, 46, 4); ctx.fillRect(40, 136, 46, 3); ctx.fillRect(44, 150, 3, 9); ctx.fillRect(79, 150, 3, 9);
    // 주민 둘: 하나는 벤치에 앉아 읽고, 하나는 왔다 갔다. 사람 하나가 달려든다
    figure(ctx, 63, 160, 1, 'seat', 1, INK, t, false);
    const wx = 230 + Math.sin(t * 0.7) * 50; figure(ctx, wx, 168, 1.05, 'run', Math.cos(t * 0.7) >= 0 ? 1 : -1, INK, t, false);
    const px = ((t * 90) % (W + 80)) - 40; figure(ctx, px, 150, 1, px > 90 && px < 130 ? 'punch' : 'run', 1, figureColor(seed || 3), t, false);
    return;
  }
  // 사람이 만든 게임 — 이름 씨앗의 바닥색과 졸라맨
  const r = rng(hash(`card:${seed}`)); const hue = Math.floor(r() * 360);
  ctx.fillStyle = `hsl(${hue} 18% 93%)`; ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = `hsl(${hue} 14% 84%)`; ctx.fillRect(0, 130, W, H - 130);
  const poses: FigPose[] = ['stand', 'run', 'jump', 'kick', 'punch', 'read', 'swing', 'seat'];
  const i = Math.floor(t / 1.4) % poses.length;
  figure(ctx, 160, 158, 1.3, poses[i], 1, figureColor(seed), t, false);
  figure(ctx, 90 + Math.sin(t) * 20, 162, 1, 'run', Math.cos(t) >= 0 ? 1 : -1, INK, t, false);
}
