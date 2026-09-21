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
 */
import { DurableObject } from 'cloudflare:workers';

const CONTROL = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export class ClimbRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.users = null;      // uid → state (lazy from storage)
    this.lastSave = new Map();
    this.chatCount = new Map();
    this.world = null;      // { loose: {id: item}, broken: {key: {hp, brokeAt}}, npc: {who: override} } — 광장의 공유 상태
    this.worldSavedAt = 0;
  }

  async loadWorld() {
    if (this.world) return this.world;
    this.world = (await this.ctx.storage.get('world')) ?? { loose: {}, broken: {}, npc: {} };
    return this.world;
  }
  /** 낡은 것 정리 — 부서진 소품은 2분, 주민 이탈은 until 지나면, 바닥 물건은 1시간 */
  tidy(w, now) {
    for (const [k, v] of Object.entries(w.broken)) if (v.brokeAt && now - v.brokeAt > 120000) delete w.broken[k];
    for (const [k, v] of Object.entries(w.npc)) if (v.until && now > v.until + 8000) delete w.npc[k];
    for (const [k, v] of Object.entries(w.loose)) if (now - (v.at ?? now) > 3600000) delete w.loose[k];
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

  async fetch(request) {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/leave') {
      // 로그아웃 — 그 사람은 탑에서 사라진다
      const uid = Number(url.searchParams.get('uid')) || 0;
      const users = await this.load();
      if (uid && users.has(uid)) {
        const u = users.get(uid); u.status = 'gone'; u.at = Date.now(); await this.ctx.storage.put(`u:${uid}`, u);
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
    server.serializeAttachment({ uid, handle, ip: request.headers.get('cf-connecting-ip') ?? 'unknown' });
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
    try { server.send(JSON.stringify({ t: 'init', me: uid, users: [...users.values()].filter((u) => u.status !== 'gone' || u.uid === uid), world })); } catch {}
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, raw) {
    const att = ws.deserializeAttachment() ?? {};
    let m; try { m = JSON.parse(String(raw)); } catch { return; }
    const users = await this.load();
    if (m.t === 'pos' && att.uid) {
      const u = users.get(att.uid); if (!u) return;
      const x = Math.max(0, Math.min(960, Number(m.x) || 0)), y = Math.max(0, Math.min(1e7, Number(m.y) || 0));
      Object.assign(u, { x, y, pose: String(m.pose || 'stand').slice(0, 6), face: m.face === -1 ? -1 : 1, map: String(m.m || '').slice(0, 20), status: 'active', at: Date.now() });
      let bestUp = false;
      if (y > u.best + 1) { u.best = y; bestUp = true; }
      this.broadcast({ t: 'pos', uid: att.uid, x, y, pose: u.pose, face: u.face, m: u.map }, ws);
      const last = this.lastSave.get(att.uid) ?? 0;
      if (Date.now() - last > 5000) {
        this.lastSave.set(att.uid, Date.now());
        await this.ctx.storage.put(`u:${att.uid}`, u);
        if (bestUp || Date.now() - last > 30000) {
          await this.env.DB.prepare(`INSERT INTO climb_best (user_id, best, updated_at) VALUES (?1, ?2, datetime('now'))
            ON CONFLICT(user_id) DO UPDATE SET best = MAX(best, excluded.best), updated_at = datetime('now')`).bind(att.uid, Math.round(u.best)).run().catch(() => null);
        }
      }
      return;
    }
    if (m.t === 'ev' && att.uid) {
      // 세계 이벤트 — 보낸 사람 화면엔 이미 적용됐다. 상태를 갱신하고 나머지에게 중계
      const w = await this.loadWorld(); const now = Date.now(); const ev = m.ev ?? {};
      const k = String(ev.k || '');
      if (k === 'drop' && ev.id) w.loose[String(ev.id).slice(0, 40)] = { item: String(ev.item).slice(0, 12), m: String(ev.m).slice(0, 20), x: Number(ev.x) || 0, d: Number(ev.d) || 0, from: ev.from === null ? null : Number(ev.from), dunked: ev.dunked ? String(ev.dunked).slice(0, 20) : undefined, at: now };
      else if (k === 'pick' && ev.id) delete w.loose[String(ev.id)];
      else if (k === 'break' && ev.key) w.broken[String(ev.key).slice(0, 40)] = { hp: Number(ev.hp) || 0, brokeAt: ev.brokeAt ? now : 0 };
      else if (k === 'npc' && ev.who !== undefined) { const who = Number(ev.who); if (String(ev.mode) === 'routine') delete w.npc[who]; else w.npc[who] = { mode: String(ev.mode).slice(0, 10), until: Number(ev.until) || 0, x: Number(ev.x) || 0, d: Number(ev.d) || 0, item: ev.item ? String(ev.item).slice(0, 12) : null, by: att.uid, at: now }; }
      else if (k === 'npcpos' && ev.who !== undefined) { const o = w.npc[Number(ev.who)]; if (o) { o.x = Number(ev.x) || 0; o.d = Number(ev.d) || 0; o.m = String(ev.m || ''); } }
      else if (k === 'fix' && ev.key) delete w.broken[String(ev.key)];
      else if (k === 'hitp') { /* 사람끼리 타격 — 상태는 없고 중계만 */ }
      else return;
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
    u.status = 'rest'; u.pose = 'sit'; u.at = Date.now();
    await this.ctx.storage.put(`u:${att.uid}`, u);
    this.broadcast({ t: 'rest', uid: att.uid });
  }

  async webSocketError(ws) { try { ws.close(1011, 'error'); } catch {} }
}
