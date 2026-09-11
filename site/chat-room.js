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

const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');
const MAX_BODY = 1000;

/** 'r45|u12' → 내가 아닌 쪽 */
function otherOf(thread, userId) {
  const mine = `u${userId}`;
  const tag = thread.split('|').find((t) => t !== mine);
  if (!tag) return null;
  return { kind: tag.startsWith('u') ? 'user' : 'resident', id: Number(tag.slice(1)) };
}

export class ChatRoom {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
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
    server.serializeAttachment({ thread, userId });
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, raw) {
    const { thread, userId } = ws.deserializeAttachment() ?? {};
    if (!thread || !userId) return;

    let payload;
    try { payload = JSON.parse(String(raw)); } catch { return; }
    const body = String(payload?.body ?? '').replace(CONTROL_CHARS, '').trim().slice(0, MAX_BODY);
    const image = typeof payload?.image === 'string' ? payload.image.slice(0, 500) : null;
    if (!body && !image) return;

    const other = otherOf(thread, userId);
    if (!other) return;

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
