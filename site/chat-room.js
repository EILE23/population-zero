/**
 * 대화 한 줄기를 맡는 Durable Object — 앱의 실시간 채팅.
 *
 * 폴링(2~3초마다 되묻기)으로도 대화는 굴러가지만, 그건 "곧 도착함"이지 실시간이 아니다.
 * 하나의 대화(thread)는 항상 같은 DO 로 가므로 두 사람이 같은 방에 들어오고,
 * 한쪽이 보낸 말이 다른 쪽 화면에 곧장 나타난다.
 *
 * 저장은 여전히 D1 이 한다 — DO 는 전달만 맡는다. 그래야 웹 쪽지함과 앱 채팅이 같은 기록을 본다.
 * 연결은 Hibernation API 로 받는다: 아무 말이 없는 동안 DO 는 잠들어 요금이 붙지 않고,
 * 새 말이 오면 깨어난다(수천 개의 대화를 열어 둬도 유지 비용이 거의 없다).
 */
import { DurableObject } from 'cloudflare:workers';

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const MAX_BODY = 1000;

/** 'r45|u12' → 내가 아닌 쪽 */
function otherOf(thread, userId) {
  const mine = `u${userId}`;
  const tag = thread.split('|').find((t) => t !== mine);
  if (!tag) return null;
  return { kind: tag.startsWith('u') ? 'user' : 'resident', id: Number(tag.slice(1)) };
}

export class ChatRoom extends DurableObject {
  constructor(ctx, env) {
    // 새 런타임은 DurableObject 를 상속하지 않으면 클래스를 못 찾는다 (배포가 거절된다)
    super(ctx, env);
  }

  async canDeliver(peer, thread) {
    const att = peer.deserializeAttachment() ?? {};
    const other = otherOf(thread, att.userId);
    if (!other || att.thread !== thread || !att.token) return false;
    const valid = await this.env.DB.prepare(`SELECT 1 FROM sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token=?1 AND s.user_id=?2 AND u.email_verified=1 AND julianday(s.expires_at)>julianday('now')
      AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE
        (b.user_id=?2 AND b.target_type=?3 AND b.target_id=?4) OR
        (?3='user' AND b.user_id=?4 AND b.target_type='user' AND b.target_id=?2))`)
      .bind(att.token, att.userId, other.kind, other.id).first();
    if (!valid) { try { peer.close(1008, 'Conversation unavailable'); } catch {} }
    return !!valid;
  }

  async fetch(request) {
    const notification = new URL(request.url);
    // Only the worker binding can reach this endpoint, after an authenticated write.
    if (request.method === 'POST' && notification.pathname === '/notify') {
      const message = await this.env.DB.prepare(
        'SELECT id, body, image, created_at, from_user_id FROM dms WHERE thread = ? AND id = ?',
      ).bind(notification.searchParams.get('thread'), Number(notification.searchParams.get('id'))).first();
      if (message) {
        for (const peer of this.ctx.getWebSockets()) {
          if (!await this.canDeliver(peer, notification.searchParams.get('thread'))) continue;
          try { peer.send(JSON.stringify({ type: 'message', message,
            mine: peer.deserializeAttachment()?.userId === message.from_user_id })); } catch { /* Closed peer. */ }
        }
      }
      return new Response(null, { status: 204 });
    }
    if (request.headers.get('upgrade') !== 'websocket') {
      return new Response('expected websocket', { status: 426 });
    }
    const url = new URL(request.url);
    const thread = url.searchParams.get('thread') ?? '';
    const userId = Number(url.searchParams.get('uid')) || 0;
    if (!thread || !userId) return new Response('bad request', { status: 400 });

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    // 잠든 동안에도 이 소켓이 누구의 것인지 남아 있어야 한다
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ thread, userId, token: url.searchParams.get('token'),
      ip: request.headers.get('cf-connecting-ip') ?? 'unknown' });
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, raw) {
    const { thread, userId, token, ip } = ws.deserializeAttachment() ?? {};
    if (!thread || !userId || !token) { ws.close(1008, 'Reconnect to authenticate'); return; }
    const session = await this.env.DB.prepare(
      `SELECT u.email_verified FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE s.token = ? AND s.user_id = ? AND julianday(s.expires_at) > julianday('now')`,
    ).bind(token, userId).first();
    if (!session?.email_verified) { ws.close(1008, 'Session unavailable'); return; }

    let payload;
    try { payload = JSON.parse(String(raw)); } catch { return; }
    const body = String(payload?.body ?? '').replace(CONTROL_CHARS, '').trim().slice(0, MAX_BODY);
    // Images must pass the authenticated HTTP upload validation.
    const image = null;
    if (!body && !image) return;

    const other = otherOf(thread, userId);
    if (!other) return;
    const blocked = await this.env.DB.prepare(`SELECT 1 FROM user_blocks WHERE
      (user_id=?1 AND target_type=?2 AND target_id=?3) OR (?2='user' AND user_id=?3 AND target_type='user' AND target_id=?1) LIMIT 1`)
      .bind(userId, other.kind, other.id).first();
    if (blocked) { ws.close(1008, 'Conversation unavailable'); return; }

    const allowance = await this.env.DB.prepare(
      `INSERT INTO auth_attempts (ip) SELECT ?1
       WHERE (SELECT COUNT(*) FROM auth_attempts WHERE ip = ?1 AND ts > datetime('now', '-5 minutes')) < 30`,
    ).bind(`dm:${ip ?? 'unknown'}`).run();
    if (!allowance.meta.changes) {
      ws.send(JSON.stringify({ type: 'error', error: 'rate' }));
      return;
    }

    // 기록은 D1 에 — 웹 쪽지함이 읽는 곳과 같아야 한다
    const { meta } = await this.env.DB.prepare(
      `INSERT INTO dms (thread, from_user_id, to_user_id, to_resident_id, body, image) VALUES (?, ?, ?, ?, ?, ?)`,
    ).bind(
      thread,
      userId,
      other.kind === 'user' ? other.id : null,
      other.kind === 'resident' ? other.id : null,
      body,
      image,
    ).run();

    const message = {
      id: Number(meta.last_row_id),
      body,
      image,
      created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      from_user_id: userId,
    };

    // 방에 있는 모두에게 — 보낸 사람 화면에서는 자기가 보낸 것으로 표시된다
    for (const peer of this.ctx.getWebSockets()) {
      if (!await this.canDeliver(peer, thread)) continue;
      const att = peer.deserializeAttachment() ?? {};
      try {
        peer.send(JSON.stringify({ type: 'message', message, mine: att.userId === userId }));
      } catch { /* 끊긴 소켓은 곧 정리된다 */ }
    }
  }

  async webSocketClose(ws, code, reason, wasClean) {
    try { ws.close(code, reason); } catch { /* 이미 닫혔다 */ }
    void wasClean;
  }

  async webSocketError(ws) {
    try { ws.close(1011, 'error'); } catch { /* 이미 닫혔다 */ }
  }
}
