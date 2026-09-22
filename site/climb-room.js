/**
 * Climb 의 방 — 탑 하나, DO 하나. 사람들의 위치를 들고 있다가 서로에게 보여 준다.
 *
 * 저장의 규칙(운영자):
 *   게임 화면에 있는 사람 → 서 있고 움직인다 (10Hz 로 위치를 보낸다)
 *   로그인은 했지만 화면을 떠난 사람 → 그 자리에 앉아 쉰다 (소켓이 닫히면 status=rest, 자리는 남는다)
 *   로그아웃한 사람 → 화면에서 사라진다. 자리는 남는다 — 다시 로그인하면 거기서 이어서 한다 (로그아웃이 /leave 로 알린다)
 * 위치는 DO 저장소에 실시간으로(5초 간격) 남고, 최고 높이는 D1 climb_best 에도 쓴다(순위표·SSR 이 읽는다).
 * 로그아웃 방문자는 구경만 한다(spectator). 채팅은 저장하지 않는다 — 성의 없이 흘러가는 게 맞다.
 * Hibernation API: 아무도 움직이지 않으면 잠들고 요금이 붙지 않는다.
 *
 * 한 사람이 방 전체를 흔들 수 없다: 위치는 연결마다 15Hz 까지만 중계하고(그 사이 것은 마지막 값만 남는다),
 * 이벤트는 초당 10개, 메시지는 2KB 까지. 중계는 받은 원문이 아니라 검증해 다시 만든 객체다.
 */
import { DurableObject } from 'cloudflare:workers';

const CONTROL = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const MAX_RAW = 2048;          // 메시지 한 개의 바이트 상한
const POS_INTERVAL = 66;       // 위치 중계 최소 간격 ms (≈15Hz) — 클라이언트 권장 10~15Hz 를 서버가 강제한다
const EV_PER_SEC = 10;         // 세계 이벤트 초당 상한 (연결당)
const LOOSE_MAX = 200;         // 바닥에 놓인 물건 상한 — 넘치면 가장 오래된 것부터
const SAVE_MS = 5000, FALLBACK_MS = 30000;

export class ClimbRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.users = null;      // uid → state (lazy from storage)
    this.lastSave = new Map();
    this.savedBest = new Map(); // uid → D1 에 마지막으로 쓴 best. 5초 저장 시점의 bestUp 만 보면 그 사이의 최고점을 놓친다(실측)
    this.lastPos = new Map();   // uid → 마지막 위치 중계 시각
    this.evTimes = new Map();   // uid → 최근 1초의 이벤트 시각들
    this.chatCount = new Map();
    this.world = null;      // { loose: {id: item}, broken: {key: {hp, brokeAt}}, npc: {who: override} } — 광장의 공유 상태
    this.worldSavedAt = 0;
  }

  async loadWorld() {
    if (this.world) return this.world;
    this.world = (await this.ctx.storage.get('world')) ?? { loose: {}, broken: {}, npc: {} };
    return this.world;
  }
  /** 낡은 것 정리 — 부서진 소품은 2분, 주민 이탈은 until 지나면, 바닥 물건은 1시간, 그리고 개수 상한 */
  tidy(w, now) {
    for (const [k, v] of Object.entries(w.broken)) if (v.brokeAt && now - v.brokeAt > 120000) delete w.broken[k];
    for (const [k, v] of Object.entries(w.npc)) if (v.until && now > v.until + 8000) delete w.npc[k];
    for (const [k, v] of Object.entries(w.loose)) if (now - (v.at ?? now) > 3600000) delete w.loose[k];
    const keys = Object.keys(w.loose);
    if (keys.length > LOOSE_MAX) for (const k of keys.sort((a, b) => (w.loose[a].at ?? 0) - (w.loose[b].at ?? 0)).slice(0, keys.length - LOOSE_MAX)) delete w.loose[k];
  }

  async load() {
    if (this.users) return this.users;
    this.users = new Map();
    const all = await this.ctx.storage.list({ prefix: 'u:' });
    for (const [k, v] of all) this.users.set(Number(k.slice(2)), v);
    return this.users;
  }

  /** 쉬는 사람 중 살아 있는 세션이 하나도 없는 사람(만료·다른 기기서 로그아웃)은 사라진다 — 누가 들어올 때마다, 10분에 한 번 */
  async sweep(users) {
    if (Date.now() - (this.sweptAt ?? 0) < 600000) return;
    this.sweptAt = Date.now();
    const resting = [...users.values()].filter((u) => u.status === 'rest').map((u) => u.uid);
    if (!resting.length) return;
    const { results } = await this.env.DB.prepare(
      `SELECT DISTINCT user_id FROM sessions WHERE user_id IN (${resting.map(() => '?').join(',')}) AND julianday(expires_at) > julianday('now')`,
    ).bind(...resting).all().catch(() => ({ results: null }));
    if (!results) return;
    const alive = new Set(results.map((r) => r.user_id));
    for (const uid of resting) {
      if (alive.has(uid)) continue;
      const u = users.get(uid); u.status = 'gone'; await this.ctx.storage.put(`u:${uid}`, u);
      this.broadcast({ t: 'leave', uid });
    }
  }

  broadcast(msg, except = null) {
    const raw = JSON.stringify(msg);
    for (const peer of this.ctx.getWebSockets()) {
      if (peer === except) continue;
      try { peer.send(raw); } catch { /* 끊긴 소켓은 곧 정리된다 */ }
    }
  }

  /** 최고 높이를 D1 에 — 마지막으로 쓴 값보다 높을 때만. 실패하면 savedBest 를 올리지 않아 다음 기회에 다시 쓴다 */
  async flushBest(uid, u) {
    const best = Math.round(u.best);
    if (best <= (this.savedBest.get(uid) ?? -1)) return;
    try {
      await this.env.DB.prepare(`INSERT INTO climb_best (user_id, best, updated_at) VALUES (?1, ?2, datetime('now'))
        ON CONFLICT(user_id) DO UPDATE SET best = MAX(best, excluded.best), updated_at = datetime('now')`).bind(uid, best).run();
      this.savedBest.set(uid, best);
    } catch { /* dirty 로 남는다 */ }
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/leave') {
      // 로그아웃 — 그 사람은 탑에서 사라진다
      const uid = Number(url.searchParams.get('uid')) || 0;
      const users = await this.load();
      if (uid && users.has(uid)) {
        const u = users.get(uid); u.status = 'gone'; u.at = Date.now(); await this.ctx.storage.put(`u:${uid}`, u);
        await this.flushBest(uid, u); // 떠나기 전에 기록부터
        this.broadcast({ t: 'leave', uid });
        for (const peer of this.ctx.getWebSockets()) { if (peer.deserializeAttachment()?.uid === uid) { try { peer.close(1000, 'logged out'); } catch {} } }
      }
      return new Response(null, { status: 204 });
    }
    if (request.headers.get('upgrade') !== 'websocket') return new Response('expected websocket', { status: 426 });
    const uid = Number(url.searchParams.get('uid')) || 0;
    const handle = (url.searchParams.get('handle') || '').slice(0, 40);
    const avatar = (url.searchParams.get('avatar') || '').slice(0, 300);
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    const room = (url.searchParams.get('room') || 'tower').slice(0, 30);
    server.serializeAttachment({ uid, handle, room, ip: request.headers.get('cf-connecting-ip') ?? 'unknown' });
    const users = await this.load();
    await this.sweep(users);
    let me = null;
    if (uid) {
      me = users.get(uid) ?? { uid, handle, avatar, x: 480, y: 0, best: 0, face: 1 };
      me = { ...me, handle, avatar, status: 'active', pose: 'stand', at: Date.now() };
      users.set(uid, me);
      await this.ctx.storage.put(`u:${uid}`, me);
      this.broadcast({ t: 'user', u: me }, server);
    }
    // 처음 한 번: 탑에 있는 모두 (활동 중이든 쉬는 중이든)
    // 로그아웃한 사람(gone)은 남에게 보이지 않는다 — 자리만 저장돼 있다
    const world = await this.loadWorld(); this.tidy(world, Date.now());
    // now: 서버 시각 — 클라이언트가 자기 시계와의 차이를 재서 결정적 일과(주민 위치)를 같은 시각 기준으로 돈다. 시계가 몇 초 어긋난 두 사람은 같은 주민을 다른 곳에서 봤다
    try { server.send(JSON.stringify({ t: 'init', me: uid, now: Date.now(), users: [...users.values()].filter((u) => u.status !== 'gone' || u.uid === uid), world })); } catch {}
    return new Response(null, { status: 101, webSocket: client });
  }

  /** 세계 이벤트를 검증해 다시 만든다 — 받은 원문을 그대로 중계하면 남이 만든 임의 객체가 모두의 화면에 들어간다 */
  cleanEvent(ev) {
    const k = String(ev.k || '');
    const num = (v, lo, hi) => Math.max(lo, Math.min(hi, Number(v) || 0));
    if (k === 'drop' && ev.id) return { k, id: String(ev.id).slice(0, 40), item: String(ev.item ?? '').slice(0, 12), m: String(ev.m ?? '').slice(0, 20), x: num(ev.x, -1e6, 1e6), d: num(ev.d, -1e6, 1e6), from: ev.from === null || ev.from === undefined ? null : num(ev.from, 0, 1e9), dunked: ev.dunked ? String(ev.dunked).slice(0, 20) : undefined };
    if (k === 'pick' && ev.id) return { k, id: String(ev.id).slice(0, 40) };
    if (k === 'break' && ev.key) return { k, key: String(ev.key).slice(0, 40), hp: num(ev.hp, 0, 1e6), brokeAt: !!ev.brokeAt };
    if (k === 'npc' && ev.who !== undefined) return { k, who: num(ev.who, 0, 1e6), mode: String(ev.mode ?? '').slice(0, 10), until: num(ev.until, 0, 1e13), x: num(ev.x, -1e6, 1e6), d: num(ev.d, -1e6, 1e6), item: ev.item ? String(ev.item).slice(0, 12) : null };
    if (k === 'npcpos' && ev.who !== undefined) return { k, who: num(ev.who, 0, 1e6), x: num(ev.x, -1e6, 1e6), d: num(ev.d, -1e6, 1e6), m: String(ev.m ?? '').slice(0, 20) };
    if (k === 'fix' && ev.key) return { k, key: String(ev.key).slice(0, 40) };
    if (k === 'hitp') return { k, who: num(ev.who, 0, 1e9), dx: num(ev.dx, -100, 100), dy: num(ev.dy, -100, 100) };
    return null;
  }

  async webSocketMessage(ws, raw) {
    const att = ws.deserializeAttachment() ?? {};
    if (typeof raw !== 'string' || raw.length > MAX_RAW) return; // 큰 메시지는 게임에 없다
    let m; try { m = JSON.parse(raw); } catch { return; }
    if (!m || typeof m !== 'object') return;
    const users = await this.load();
    const now = Date.now();
    if (m.t === 'pos' && att.uid) {
      const u = users.get(att.uid); if (!u) return;
      const tower = !att.room || att.room === 'tower'; // 광장·게임 방은 지도가 넓다(3200+) — 960 으로 자르면 남들에게 제자리에 박혀 자세만 바뀌는 사람으로 보인다
      const x = Math.max(0, Math.min(tower ? 960 : 20000, Number(m.x) || 0)), y = Math.max(0, Math.min(1e7, Number(m.y) || 0));
      Object.assign(u, { x, y, z: Math.max(0, Math.min(400, Number(m.z) || 0)), pose: String(m.pose || 'stand').slice(0, 6), face: m.face === -1 ? -1 : 1, map: String(m.m || '').slice(0, 20), stack: String(m.s || '').slice(0, 80), status: 'active', at: now });
      if (tower && y > u.best + 1) u.best = y; // 최고 높이는 탑에서만(광장의 y 는 깊이다)
      // 중계는 15Hz 까지 — 그보다 잦은 것은 상태만 갱신하고 보내지 않는다(다음 중계가 최신 값을 실어 나른다)
      const lastPos = this.lastPos.get(att.uid) ?? 0;
      if (now - lastPos >= POS_INTERVAL) {
        this.lastPos.set(att.uid, now);
        this.broadcast({ t: 'pos', uid: att.uid, x, y, z: u.z, pose: u.pose, face: u.face, m: u.map, s: u.stack }, ws);
      }
      const last = this.lastSave.get(att.uid) ?? 0;
      if (now - last > SAVE_MS) {
        this.lastSave.set(att.uid, now);
        await this.ctx.storage.put(`u:${att.uid}`, u);
        await this.flushBest(att.uid, u); // 이 5초 사이에 최고점을 찍고 내려왔어도 best 는 남아 있다
      }
      return;
    }
    if (m.t === 'ev' && att.uid) {
      // 초당 EV_PER_SEC 개 — 그 이상은 버린다
      const times = (this.evTimes.get(att.uid) ?? []).filter((t) => now - t < 1000);
      if (times.length >= EV_PER_SEC) return;
      times.push(now); this.evTimes.set(att.uid, times);
      const ev = this.cleanEvent(m.ev ?? {});
      if (!ev) return;
      // 세계 이벤트 — 보낸 사람 화면엔 이미 적용됐다. 상태를 갱신하고 나머지에게 중계
      const w = await this.loadWorld();
      const k = ev.k;
      if (k === 'drop') w.loose[ev.id] = { item: ev.item, m: ev.m, x: ev.x, d: ev.d, from: ev.from, dunked: ev.dunked, at: now };
      else if (k === 'pick') delete w.loose[ev.id];
      else if (k === 'break') w.broken[ev.key] = { hp: ev.hp, brokeAt: ev.brokeAt ? now : 0 };
      else if (k === 'npc') { if (ev.mode === 'routine') delete w.npc[ev.who]; else w.npc[ev.who] = { mode: ev.mode, until: ev.until, x: ev.x, d: ev.d, item: ev.item, by: att.uid, at: now }; }
      else if (k === 'npcpos') { const o = w.npc[ev.who]; if (o) { o.x = ev.x; o.d = ev.d; o.m = ev.m; } }
      else if (k === 'fix') delete w.broken[ev.key];
      /* hitp: 사람끼리 타격 — 상태는 없고 중계만 */
      this.tidy(w, now);
      this.broadcast({ t: 'ev', ev, by: att.uid }, ws);
      if (now - this.worldSavedAt > 4000) { this.worldSavedAt = now; await this.ctx.storage.put('world', w); }
      return;
    }
    if (m.t === 'chat') {
      if (!att.uid) return;
      const body = String(m.body ?? '').replace(CONTROL, '').replace(/\s+/g, ' ').trim().slice(0, 140);
      if (!body) return;
      const n = (this.chatCount.get(att.uid) ?? 0) + 1; this.chatCount.set(att.uid, n);
      if (n > 60) return; // 이 DO 가 깨어 있는 동안 60줄이면 충분하다
      this.broadcast({ t: 'chat', uid: att.uid, handle: att.handle, body });
    }
  }

  async webSocketClose(ws, code, reason) {
    const att = ws.deserializeAttachment() ?? {};
    try { ws.close(code, reason); } catch {}
    if (!att.uid) return;
    // 같은 사람의 다른 탭이 아직 있으면 그대로
    for (const peer of this.ctx.getWebSockets()) { if (peer !== ws && peer.deserializeAttachment()?.uid === att.uid) return; }
    const users = await this.load();
    const u = users.get(att.uid); if (!u) return;
    await this.flushBest(att.uid, u); // 떠나는 순간의 최고점 — 다음 5초 저장은 오지 않는다
    if (u.status === 'gone') return; // 로그아웃(/leave)이 먼저 왔다 — 닫힘 이벤트가 그걸 '쉬는 중' 으로 되돌리면 안 된다
    u.status = 'rest'; u.pose = 'sit'; u.at = Date.now();
    await this.ctx.storage.put(`u:${att.uid}`, u);
    this.broadcast({ t: 'rest', uid: att.uid });
  }

  async webSocketError(ws) { try { ws.close(1011, 'error'); } catch {} }
}
