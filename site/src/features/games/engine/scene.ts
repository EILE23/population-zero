/**
 * 2.5D 무대 — Square 와 같은 셈법. 깊이 d(0=뒤, 1=앞)를 화면 y 와 크기로 바꾼다. 캔버스는 VIEW_W 기준으로 그리고 DPR 은 배율 s 로 처리한다.
 */
export interface Scene {
  W: number; H: number; ground: number; top: number; depth: number;
  /** 깊이 → 발끝 y */
  dy(d: number): number;
  /** 깊이 → 크기 배율(뒤 0.7 ~ 앞 1.0) */
  ds(d: number): number;
  /** 무대 거리 — 깊이 차이는 400px 로 친다(Square 와 같다) */
  dist(ax: number, ad: number, bx: number, bd: number): number;
  /** 카메라를 목표에 부드럽게, 지도 폭 안에서 */
  follow(cam: number, targetX: number, worldW: number, dt: number): number;
  /** 캔버스를 부모 폭에 맞추고 DPR 배율을 돌려준다 */
  fit(c: HTMLCanvasElement, parentW: number): number;
}
export function scene(W = 960, H = 470, ground = 330, depth = 130): Scene {
  const top = ground - depth;
  return {
    W, H, ground, top, depth,
    dy: (d) => top + d * depth,
    ds: (d) => 0.7 + 0.3 * d,
    dist: (ax, ad, bx, bd) => Math.hypot(ax - bx, (ad - bd) * 400),
    follow: (cam, targetX, worldW, dt) => cam + (Math.max(0, Math.min(worldW - W, targetX - W / 2)) - cam) * Math.min(1, dt * 6),
    fit: (c, parentW) => { const width = Math.min(W, parentW); c.width = Math.round(width * devicePixelRatio); c.height = Math.round(width * (H / W) * devicePixelRatio); c.style.width = `${width}px`; c.style.height = `${width * (H / W)}px`; return c.width / W; },
  };
}
