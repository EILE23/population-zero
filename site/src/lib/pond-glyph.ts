import type { G } from './pond-items';
import { rng } from './tower';

/**
 * 잡힌 것의 낙서 — 캔버스에 선으로. 카드·물 위 표시·주민 말풍선이 같은 걸 쓴다.
 * 중심 (x, y), 크기 s(대략 폭). seed 로 물고기 색·비율이 조금씩 달라 같은 종류도 다 다르게 보인다.
 */
/** 종 — key 앞머리로 색·무늬·수염을 정한다. 모르는 물고기는 씨앗 색 */
type Pat = 'none' | 'stripes' | 'spots' | 'band' | 'patches';
function species(key: string, hue: number): { body: string; belly: string; mark: string; fin: string; pattern: Pat; whiskers: boolean } {
  const k = key.replace(/\d+$/, '');
  const T: Record<string, [string, string, string, string, Pat, boolean]> = {
    carp: ['#b9863f', '#e6d3a5', '#8a5f2a', '#c99a55', 'spots', true], koi: ['#f4f1ec', '#ffffff', '#e0602a', '#f4d9c8', 'patches', true],
    bass: ['#5f7f4a', '#d9dfb8', '#2f4a2a', '#7a9a5e', 'band', false], catfish: ['#6b6a5e', '#c9c4b0', '#4a4a40', '#8a887a', 'none', true],
    trout: ['#8fa88a', '#f0d9d0', '#d46a7a', '#a9b89f', 'spots', false], perch: ['#b7a65a', '#efe7b8', '#4f4a2a', '#d98a3a', 'stripes', false],
    pike: ['#6f8a5a', '#d7dfc0', '#3b4f2f', '#8ea87a', 'spots', false], eel: ['#4b5a4a', '#a8b09a', '#2e3a2c', '#5f705a', 'none', false],
    bluegill: ['#4f6d8a', '#d7c9a0', '#2c3f57', '#e0743a', 'stripes', false], crappie: ['#9aa39c', '#e7e9de', '#3f4a44', '#b4bcb3', 'spots', false],
    tilapia: ['#8f9aa3', '#dfe3e6', '#5f6a72', '#aab3ba', 'stripes', false], salmon: ['#c98a80', '#f4d9cf', '#8a4a44', '#d9a49a', 'spots', false],
    tuna: ['#3b5a7a', '#cfd9e6', '#233a52', '#5a7a9a', 'none', false], goldfish: ['#f0a03a', '#ffd9a0', '#c96a1a', '#ffb860', 'none', false],
    minnow: ['#b8c4c8', '#eef2f3', '#7a8a90', '#c9d3d6', 'band', false], sturgeon: ['#7a7d78', '#c9cbc4', '#4a4d48', '#9a9d98', 'none', true],
    walleye: ['#b09a5a', '#ede0b0', '#6a5a2a', '#c9b070', 'none', false], zander: ['#a09a7a', '#e6e0c8', '#5a5540', '#b8b090', 'stripes', false],
    bream: ['#c9b98a', '#efe6c8', '#8a7a4a', '#d9c9a0', 'none', false], roach: ['#b8c0c8', '#f0f2f4', '#7a8088', '#e0603a', 'none', false],
    piranha: ['#8a5a5a', '#e6b8b8', '#4a2a2a', '#b07070', 'spots', false], betta: ['#6a3a9a', '#c9a0e6', '#3a1a5a', '#9a5ac9', 'none', false],
    guppy: ['#e08a3a', '#ffd0a0', '#3a6ad0', '#f0a860', 'patches', false], mackerel: ['#4a7a8a', '#d0e6ec', '#1f3a44', '#6a9aaa', 'stripes', false],
    herring: ['#c04a4a', '#f0c0c0', '#7a1a1a', '#d97070', 'none', false], sardine: ['#8a9aa8', '#e6ecf0', '#4a5a68', '#a8b8c4', 'band', false],
    cod: ['#8a8a6a', '#e0e0c8', '#4a4a30', '#a8a888', 'spots', true], swordfish: ['#4a5a7a', '#cfd6e6', '#2a3a5a', '#6a7a9a', 'none', false],
    marlin: ['#3a4a8a', '#c0c8e6', '#1a2a5a', '#5a6aaa', 'stripes', false], smelt: ['#c8d0d8', '#f4f6f8', '#8a9aa8', '#d8e0e8', 'band', false],
  };
  const t = T[k];
  if (t) return { body: t[0], belly: t[1], mark: t[2], fin: t[3], pattern: t[4], whiskers: t[5] };
  const body = `hsl(${hue} 50% 58%)`;
  return { body, belly: `hsl(${hue} 45% 82%)`, mark: `hsl(${hue} 55% 35%)`, fin: `hsl(${hue} 50% 70%)`, pattern: (['none', 'stripes', 'spots', 'band'] as const)[hue % 4], whiskers: false };
}

export function drawGlyph(ctx: CanvasRenderingContext2D, g: G, x: number, y: number, s: number, seed = 1, ink = '#1b0c15', key = '') {
  const r = rng(seed);
  ctx.save(); ctx.translate(x, y); ctx.lineWidth = Math.max(1.5, s * 0.045); ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  ctx.strokeStyle = ink; ctx.fillStyle = ink;
  const hue = Math.floor(r() * 360);
  const body = `hsl(${hue} 55% 62%)`;
  const P = (pts: number[][], close = false, fill?: string) => { ctx.beginPath(); pts.forEach(([px, py], i) => (i ? ctx.lineTo(px * s, py * s) : ctx.moveTo(px * s, py * s))); if (close) ctx.closePath(); if (fill) { ctx.fillStyle = fill; ctx.fill(); ctx.fillStyle = ink; } ctx.stroke(); };
  const E = (cx: number, cy: number, rx: number, ry: number, fill?: string) => { ctx.beginPath(); ctx.ellipse(cx * s, cy * s, rx * s, ry * s, 0, 0, 6.29); if (fill) { ctx.fillStyle = fill; ctx.fill(); ctx.fillStyle = ink; } ctx.stroke(); };
  const eye = (cx: number, cy: number) => { ctx.beginPath(); ctx.arc(cx * s, cy * s, s * 0.03, 0, 6.29); ctx.fill(); };
  switch (g) {
    case 'fish': case 'big': case 'long': case 'flat': {
      const sp = species(key, hue);
      const k = g === 'big' ? 1.3 : 1;
      const rx = (g === 'long' ? 0.5 : 0.34) * k, ry = (g === 'flat' ? 0.3 : g === 'long' ? 0.11 : 0.19) * k;
      // 몸: 앞은 뭉툭, 뒤는 좁아지는 베지어
      ctx.beginPath();
      ctx.moveTo(-rx * s, 0);
      ctx.bezierCurveTo(-rx * 0.6 * s, -ry * 1.35 * s, rx * 0.5 * s, -ry * 1.2 * s, rx * s, -ry * 0.25 * s);
      ctx.bezierCurveTo(rx * 0.5 * s, ry * 1.2 * s, -rx * 0.6 * s, ry * 1.35 * s, -rx * s, 0);
      ctx.closePath(); ctx.fillStyle = sp.body; ctx.fill(); ctx.stroke();
      // 배는 밝게, 무늬는 몸 안에만
      ctx.save(); ctx.clip(); ctx.fillStyle = sp.belly; ctx.beginPath(); ctx.ellipse(-rx * 0.1 * s, ry * 0.55 * s, rx * 0.8 * s, ry * 0.5 * s, 0, 0, 6.29); ctx.fill();
      ctx.fillStyle = sp.mark; ctx.strokeStyle = sp.mark;
      if (sp.pattern === 'stripes') for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.moveTo((-rx * 0.6 + i * rx * 0.28) * s, -ry * 1.2 * s); ctx.lineTo((-rx * 0.5 + i * rx * 0.28) * s, ry * 0.4 * s); ctx.stroke(); }
      if (sp.pattern === 'spots') for (let i = 0; i < 7; i++) { ctx.beginPath(); ctx.arc((-rx * 0.7 + r() * rx * 1.3) * s, (-ry * 0.6 + r() * ry * 0.9) * s, s * 0.022, 0, 6.29); ctx.fill(); }
      if (sp.pattern === 'band') { ctx.lineWidth = s * 0.05; ctx.beginPath(); ctx.moveTo(-rx * 0.9 * s, 0); ctx.lineTo(rx * 0.9 * s, -ry * 0.1 * s); ctx.stroke(); ctx.lineWidth = Math.max(1.5, s * 0.045); }
      if (sp.pattern === 'patches') { ctx.beginPath(); ctx.ellipse(-rx * 0.3 * s, -ry * 0.4 * s, rx * 0.25 * s, ry * 0.5 * s, 0.3, 0, 6.29); ctx.fill(); ctx.beginPath(); ctx.ellipse(rx * 0.35 * s, ry * 0.2 * s, rx * 0.2 * s, ry * 0.4 * s, -0.4, 0, 6.29); ctx.fill(); }
      ctx.restore(); ctx.strokeStyle = ink; ctx.fillStyle = ink;
      // 꼬리·등지느러미·가슴지느러미
      P([[rx, -ry * 0.25], [rx + 0.2 * k, -ry * 1.1], [rx + 0.14 * k, 0], [rx + 0.2 * k, ry * 1.1], [rx, ry * 0.25]], true, sp.fin);
      P([[-rx * 0.35, -ry * 1.15], [-rx * 0.15, -ry * 1.75], [rx * 0.35, -ry * 1.6], [rx * 0.45, -ry * 1.05]], true, sp.fin);
      P([[-rx * 0.35, ry * 0.5], [-rx * 0.1, ry * 1.1], [rx * 0.15, ry * 0.7]], true, sp.fin);
      // 아가미·눈·입·수염
      ctx.beginPath(); ctx.arc(-rx * 0.45 * s, 0, ry * 0.9 * s, -1.1, 1.1); ctx.stroke();
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(-rx * 0.66 * s, -ry * 0.3 * s, s * 0.05, 0, 6.29); ctx.fill(); ctx.stroke();
      ctx.fillStyle = ink; ctx.beginPath(); ctx.arc(-rx * 0.65 * s, -ry * 0.3 * s, s * 0.025, 0, 6.29); ctx.fill();
      P([[-rx * 1.0, ry * 0.15], [-rx * 0.82, ry * 0.3]]);
      if (sp.whiskers) { P([[-rx * 0.95, ry * 0.2], [-rx * 1.25, ry * 0.55]]); P([[-rx * 0.95, ry * 0.2], [-rx * 1.2, -ry * 0.1]]); }
      break;
    }
    case 'shark': E(0, 0, 0.5, 0.17, '#9aa5ad'); P([[0.5, 0], [0.62, -0.18], [0.6, 0.12]], true, '#9aa5ad'); P([[-0.05, -0.17], [0.05, -0.4], [0.18, -0.17]], true, '#9aa5ad'); eye(-0.3, -0.05); P([[-0.45, 0.05], [-0.3, 0.1], [-0.2, 0.05]]); break;
    case 'octo': E(0, -0.1, 0.25, 0.22, body); for (let i = 0; i < 6; i++) P([[-0.2 + i * 0.08, 0.08], [-0.25 + i * 0.1, 0.3 + (i % 2) * 0.08]]); eye(-0.08, -0.12); eye(0.08, -0.12); break;
    case 'jelly': ctx.beginPath(); ctx.arc(0, -0.05 * s, 0.25 * s, Math.PI, 0); ctx.stroke(); for (let i = 0; i < 5; i++) P([[-0.2 + i * 0.1, -0.05], [-0.22 + i * 0.1, 0.25 + (i % 2) * 0.05]]); break;
    case 'crab': E(0, 0, 0.28, 0.16, '#d9694a'); P([[-0.28, 0], [-0.42, -0.15]]); P([[0.28, 0], [0.42, -0.15]]); for (const d of [-1, 1]) for (let i = 0; i < 3; i++) P([[d * (0.1 + i * 0.08), 0.12], [d * (0.15 + i * 0.1), 0.26]]); eye(-0.08, -0.1); eye(0.08, -0.1); break;
    case 'turtle': E(0, 0, 0.3, 0.2, '#6b8f5a'); E(0.36, -0.02, 0.08, 0.07); for (const d of [-1, 1]) { P([[d * 0.2, 0.15], [d * 0.28, 0.28]]); P([[d * 0.1, -0.18], [d * 0.2, -0.3]]); } break;
    case 'frog': E(0, 0.05, 0.25, 0.18, '#79a44a'); E(-0.1, -0.16, 0.07, 0.07, '#fff'); E(0.1, -0.16, 0.07, 0.07, '#fff'); eye(-0.1, -0.16); eye(0.1, -0.16); P([[-0.1, 0.1], [0.1, 0.1]]); break;
    case 'snake': P([[-0.5, 0.1], [-0.3, -0.1], [-0.1, 0.1], [0.1, -0.1], [0.3, 0.1], [0.5, -0.05]]); eye(0.45, -0.08); break;
    case 'duck': E(0, 0.05, 0.3, 0.18, '#f0e6b3'); E(0.25, -0.18, 0.11, 0.1, '#f0e6b3'); P([[0.36, -0.18], [0.5, -0.14], [0.36, -0.1]], true, '#e0a13a'); eye(0.28, -0.22); break;
    case 'boot': P([[-0.15, -0.3], [-0.15, 0.05], [0.3, 0.05], [0.3, 0.2], [-0.3, 0.2], [-0.3, -0.3]], true, '#8b6b4a'); break;
    case 'shoe': P([[-0.3, 0.1], [0.1, 0.1], [0.35, -0.05], [0.3, 0.2], [-0.3, 0.2]], true, '#5fb3a1'); break;
    case 'can': P([[-0.15, -0.25], [0.15, -0.25], [0.15, 0.25], [-0.15, 0.25]], true, '#b9b1b6'); E(0, -0.25, 0.15, 0.05); break;
    case 'bottle': P([[-0.08, -0.35], [0.08, -0.35], [0.08, -0.2], [0.16, -0.1], [0.16, 0.3], [-0.16, 0.3], [-0.16, -0.1], [-0.08, -0.2]], true, '#bfe0d4'); break;
    case 'weed': for (let i = 0; i < 4; i++) P([[-0.2 + i * 0.13, 0.3], [-0.25 + i * 0.13 + r() * 0.1, -0.1 - r() * 0.2]]); break;
    case 'log': P([[-0.45, -0.12], [0.45, -0.12], [0.45, 0.12], [-0.45, 0.12]], true, '#8b6b4a'); E(0.45, 0, 0.05, 0.12); break;
    case 'fax': P([[-0.35, -0.15], [0.35, -0.15], [0.35, 0.2], [-0.35, 0.2]], true, '#d7d2d5'); P([[-0.2, -0.15], [-0.2, -0.32], [0.2, -0.32], [0.2, -0.15]]); for (let i = 0; i < 3; i++) P([[-0.25 + i * 0.12, 0.05], [-0.2 + i * 0.12, 0.05]]); break;
    case 'paper': P([[-0.22, -0.3], [0.22, -0.3], [0.22, 0.3], [-0.22, 0.3]], true, '#fff'); for (let i = 0; i < 4; i++) P([[-0.14, -0.18 + i * 0.12], [0.14, -0.18 + i * 0.12]]); break;
    case 'cat': E(0, 0.05, 0.22, 0.2, '#8f8489'); P([[-0.18, -0.12], [-0.22, -0.32], [-0.06, -0.18]], true, '#8f8489'); P([[0.18, -0.12], [0.22, -0.32], [0.06, -0.18]], true, '#8f8489'); eye(-0.08, -0.02); eye(0.08, -0.02); P([[-0.3, 0.05], [-0.12, 0.08]]); P([[0.3, 0.05], [0.12, 0.08]]); break;
    case 'brick': P([[-0.3, -0.15], [0.3, -0.15], [0.3, 0.15], [-0.3, 0.15]], true, '#b3543a'); break;
    case 'tape': P([[-0.35, -0.2], [0.35, -0.2], [0.35, 0.2], [-0.35, 0.2]], true, '#2b2b2b'); E(-0.15, 0, 0.07, 0.07, '#fff'); E(0.15, 0, 0.07, 0.07, '#fff'); break;
    case 'reel': E(0, 0, 0.3, 0.3, '#5b5b5b'); E(0, 0, 0.06, 0.06); for (let i = 0; i < 4; i++) E(Math.cos(i * 1.57) * 0.17, Math.sin(i * 1.57) * 0.17, 0.05, 0.05); break;
    case 'meme': P([[-0.3, -0.25], [0.3, -0.25], [0.3, 0.25], [-0.3, 0.25]], true, '#fff'); P([[-0.2, -0.1], [0.2, -0.1]]); P([[-0.2, 0.12], [0.2, 0.12]]); break;
    case 'person': P([[0, -0.1], [0, 0.15]]); P([[0, 0.15], [-0.12, 0.38]]); P([[0, 0.15], [0.12, 0.38]]); P([[0, -0.02], [-0.15, 0.1]]); P([[0, -0.02], [0.15, 0.1]]); ctx.beginPath(); ctx.arc(0, -0.2 * s, 0.09 * s, 0, 6.29); ctx.fill(); break;
    case 'ghost': ctx.beginPath(); ctx.arc(0, -0.15 * s, 0.22 * s, Math.PI, 0); ctx.lineTo(0.22 * s, 0.4 * s); for (let i = 0; i < 4; i++) ctx.lineTo((0.22 - (i + 0.5) * 0.11) * s, (0.32 + (i % 2) * 0.08) * s); ctx.lineTo(-0.22 * s, 0.4 * s); ctx.closePath(); ctx.fillStyle = '#fff'; ctx.fill(); ctx.stroke(); ctx.fillStyle = ink; eye(-0.08, -0.15); eye(0.08, -0.15); break;
    case 'moon': E(0, 0, 0.3, 0.3, '#f2e7a8'); E(-0.1, -0.05, 0.05, 0.05); E(0.1, 0.1, 0.04, 0.04); break;
    case 'pigeon': E(0, 0.05, 0.25, 0.16, '#9aa5ad'); E(0.24, -0.1, 0.09, 0.08, '#9aa5ad'); P([[0.33, -0.1], [0.42, -0.08]]); eye(0.26, -0.13); P([[-0.1, 0.2], [-0.12, 0.32]]); P([[0.05, 0.2], [0.03, 0.32]]); break;
    case 'horse': P([[-0.3, 0.3], [-0.3, -0.05], [0.25, -0.05], [0.25, 0.3]]); P([[0.25, -0.05], [0.4, -0.35], [0.5, -0.3]]); P([[-0.3, -0.05], [0.25, -0.05], [0.25, 0.1], [-0.3, 0.1]], true, '#3a2f36'); break;
    case 'mirror': E(0, 0, 0.25, 0.32, '#dfe9ee'); P([[0, 0.32], [0, 0.45]]); P([[-0.12, 0.45], [0.12, 0.45]]); break;
    case 'phone': P([[-0.15, -0.3], [0.15, -0.3], [0.15, 0.3], [-0.15, 0.3]], true, '#2b2b2b'); P([[-0.1, -0.25], [0.1, -0.25], [0.1, 0.2], [-0.1, 0.2]], true, '#bfe0d4'); break;
    case 'key': E(-0.2, 0, 0.12, 0.12); P([[-0.08, 0], [0.35, 0]]); P([[0.25, 0], [0.25, 0.1]]); P([[0.35, 0], [0.35, 0.12]]); break;
    case 'ring': E(0, 0.05, 0.2, 0.2); E(0, -0.2, 0.07, 0.07, '#f2e7a8'); break;
    case 'sock': P([[-0.1, -0.35], [0.12, -0.35], [0.12, 0.05], [0.35, 0.2], [0.25, 0.32], [-0.1, 0.12]], true, '#c9a0b8'); break;
    case 'bag': P([[-0.25, -0.15], [0.25, -0.15], [0.3, 0.3], [-0.3, 0.3]], true, '#c6b8a0'); P([[-0.12, -0.15], [-0.05, -0.35], [0.05, -0.35], [0.12, -0.15]]); break;
    case 'box': P([[-0.3, -0.25], [0.3, -0.25], [0.3, 0.25], [-0.3, 0.25]], true, '#c6b8a0'); P([[-0.3, -0.05], [0.3, -0.05]]); break;
    case 'chair': P([[-0.2, -0.35], [-0.2, 0.35]]); P([[-0.2, 0], [0.2, 0], [0.2, 0.35]]); P([[-0.2, -0.35], [0.05, -0.35]]); break;
    case 'bike': E(-0.25, 0.15, 0.15, 0.15); E(0.25, 0.15, 0.15, 0.15); P([[-0.25, 0.15], [-0.05, -0.15], [0.25, 0.15], [0, 0.15], [-0.05, -0.15]]); P([[-0.05, -0.15], [-0.15, -0.3]]); break;
    case 'bone': P([[-0.3, 0], [0.3, 0]]); E(-0.32, -0.06, 0.06, 0.06); E(-0.32, 0.06, 0.06, 0.06); E(0.32, -0.06, 0.06, 0.06); E(0.32, 0.06, 0.06, 0.06); break;
    case 'coin': E(0, 0, 0.22, 0.22, '#e8c96a'); P([[-0.05, -0.1], [-0.05, 0.1]]); P([[0.05, -0.1], [0.05, 0.1]]); break;
    case 'hat': P([[-0.35, 0.1], [0.35, 0.1]]); P([[-0.2, 0.1], [-0.2, -0.25], [0.2, -0.25], [0.2, 0.1]], true, '#3a2f36'); break;
  }
  ctx.restore();
}
