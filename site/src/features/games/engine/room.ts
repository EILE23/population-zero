/**
 * 방 — 같은 게임을 보는 모두를 잇는 소켓(Durable Object `ClimbRoom`, 게임마다 방 하나: /ws/g/<slug>).
 * 방이 해 주는 것: 접속자 목록과 자리(init), 위치 중계(pos, 15Hz 권장), 사건 중계(ev — drop/pick/break/fix/npc 는 방이 기억해 뒤에 들어온 사람도 받는다), 채팅, 로그아웃(leave), 쉬기(rest).
 * 로그인 안 한 사람도 붙을 수 있다 — 받기만 한다(보내는 건 방이 버린다). 그래서 구경꾼도 같은 걸 본다.
 * 시계: init 의 now 로 서버와의 시차(skew)를 재 둔다. 결정적 연출(주민 일과 등)은 `room.now()` 를 써야 모두 같은 걸 본다.
 */
export interface RoomUser { uid: number; handle: string; avatar: string; x: number; y: number; z: number; pose: string; face: 1 | -1; map: string; stack: string; status: 'active' | 'rest' }
export interface RoomHandlers {
  init?(users: RoomUser[], world: Record<string, unknown>): void;
  user?(u: RoomUser): void;
  pos?(u: RoomUser): void;
  rest?(uid: number): void;
  leave?(uid: number): void;
  ev?(ev: Record<string, unknown>, by: number): void;
  chat?(handle: string, body: string): void;
  open?(): void;
}
export interface Room {
  /** 내 자리 — x, y(정수; 2.5D 면 깊이×1000), z(높이), pose(6자 이하), face, m(지도), s(들고 있는 것, 쉼표) */
  pos(p: { x: number; y: number; z?: number; pose: string; face: 1 | -1; m?: string; s?: string }): void;
  /** 사건 — { k: 'drop'|'pick'|'break'|'fix'|'npc'|<아무 이름>, ... } 방이 모두에게 돌린다(나 빼고) */
  ev(ev: Record<string, unknown>): void;
  chat(body: string): void;
  /** 서버 시계 기준 지금(ms) */
  now(): number;
  readonly open: boolean;
  close(): void;
}

const parseUser = (u: Record<string, unknown>): RoomUser => ({
  uid: Number(u.uid), handle: String(u.handle ?? ''), avatar: String(u.avatar ?? ''), x: Number(u.x) || 0, y: Number(u.y) || 0, z: Number(u.z) || 0,
  pose: String(u.pose ?? 'stand'), face: u.face === -1 ? -1 : 1, map: String(u.map ?? u.m ?? ''), stack: String(u.stack ?? u.s ?? ''), status: u.status === 'rest' ? 'rest' : 'active',
});

export function connectRoom(slug: string, h: RoomHandlers): Room {
  let alive = true, sock: WebSocket | null = null, retry = 0, skew = 0;
  const path = slug === 'climb' ? '/ws/climb' : slug === 'square' ? '/ws/square' : `/ws/g/${slug}`;
  const connect = () => {
    if (!alive || typeof window === 'undefined') return;
    sock = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}${path}`);
    sock.onopen = () => { retry = 0; h.open?.(); };
    sock.onmessage = (e) => {
      let m: { t: string; [k: string]: unknown }; try { m = JSON.parse(String(e.data)); } catch { return; }
      if (m.t === 'init') { if (typeof m.now === 'number' && Math.abs(m.now - Date.now()) < 6 * 3600000) skew = m.now - Date.now(); h.init?.(((m.users ?? []) as Record<string, unknown>[]).map(parseUser), (m.world ?? {}) as Record<string, unknown>); }
      else if (m.t === 'user') h.user?.(parseUser(m.u as Record<string, unknown>));
      else if (m.t === 'pos') h.pos?.(parseUser(m));
      else if (m.t === 'rest') h.rest?.(Number(m.uid));
      else if (m.t === 'leave') h.leave?.(Number(m.uid));
      else if (m.t === 'ev') h.ev?.(m.ev as Record<string, unknown>, Number(m.by ?? 0));
      else if (m.t === 'chat') h.chat?.(String(m.handle ?? ''), String(m.body ?? ''));
    };
    sock.onclose = () => { if (alive) setTimeout(connect, Math.min(15000, 1000 * 2 ** retry++)); };
  };
  connect();
  const send = (o: Record<string, unknown>) => { if (sock?.readyState === 1) sock.send(JSON.stringify(o)); };
  return {
    pos: (p) => send({ t: 'pos', x: Math.round(p.x), y: Math.round(p.y), z: Math.round(p.z ?? 0), pose: p.pose, face: p.face, m: p.m, s: p.s }),
    ev: (ev) => send({ t: 'ev', ev }),
    chat: (body) => send({ t: 'chat', body }),
    now: () => Date.now() + skew,
    get open() { return sock?.readyState === 1; },
    close: () => { alive = false; sock?.close(); },
  };
}
