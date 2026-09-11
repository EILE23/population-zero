import { useCallback, useEffect, useRef, useState } from 'react';
import { API_BASE, fetchThread, getToken, sendDm, type DmMessage } from '@/api';

type State = {
  messages: DmMessage[];
  live: boolean;
  loaded: boolean;
  connected: boolean;
  error: string | null;
};

/**
 * 대화 하나의 상태와 전송.
 *
 * 첫 화면은 언제나 HTTP 로 한 번 읽는다 — 지난 기록은 D1 에 있고, 소켓은 '지금부터'만 나른다.
 * 그 뒤에는 웹소켓(Durable Object)이 붙어 상대가 친 말이 곧바로 도착한다.
 * 소켓이 안 붙는 상황(옛 서버, 막힌 네트워크, 주민과의 대화)에서는 조용히 되묻기로 내려간다 —
 * 대화가 끊기는 것보다 조금 늦는 편이 낫다.
 *
 * 화면은 이 훅만 본다. 전송 방식을 또 바꾸더라도 ChatScreen 은 건드리지 않는다.
 */
export function useChat(thread: string, otherKind: 'user' | 'resident') {
  const [state, setState] = useState<State>({
    messages: [],
    live: otherKind === 'user',
    loaded: false,
    connected: false,
    error: null,
  });

  const lastId = useRef(0);
  const socket = useRef<WebSocket | null>(null);

  const absorb = useCallback((incoming: DmMessage[]) => {
    if (!incoming.length) return;
    lastId.current = Math.max(lastId.current, ...incoming.map((m) => m.id));
    setState((prev) => {
      const seen = new Set(prev.messages.map((m) => m.id));
      const fresh = incoming.filter((m) => !seen.has(m.id));
      return fresh.length ? { ...prev, messages: [...prev.messages, ...fresh] } : prev;
    });
  }, []);

  useEffect(() => {
    let alive = true;
    let poll: ReturnType<typeof setTimeout> | null = null;
    let ws: WebSocket | null = null;

    /** 소켓이 없을 때의 대비책 — 사람과는 자주, 주민과는 드물게 */
    const startPolling = (live: boolean) => {
      const tick = async () => {
        if (!alive) return;
        try {
          const data = await fetchThread(thread, lastId.current);
          if (!alive) return;
          absorb(data.messages);
        } catch {
          /* 한 번 실패는 넘긴다 — 다음 차례에 다시 묻는다 */
        }
        if (alive) poll = setTimeout(tick, live ? 3000 : 20000);
      };
      poll = setTimeout(tick, live ? 3000 : 20000);
    };

    (async () => {
      // 1) 지난 기록
      try {
        const data = await fetchThread(thread, 0);
        if (!alive) return;
        absorb(data.messages);
        setState((p) => ({ ...p, live: data.live, loaded: true, error: null }));

        // 2) 사람과의 대화만 소켓을 연다 — 주민은 순찰 때 답하므로 열어 둘 이유가 없다
        if (!data.live) { startPolling(false); return; }

        const token = await getToken();
        if (!token || !alive) { startPolling(true); return; }

        const url = `${API_BASE.replace(/^http/, 'ws')}/ws/dm?thread=${encodeURIComponent(thread)}&token=${encodeURIComponent(token)}`;
        ws = new WebSocket(url);
        socket.current = ws;

        ws.onopen = () => { if (alive) setState((p) => ({ ...p, connected: true })); };
        ws.onmessage = (event) => {
          if (!alive) return;
          try {
            const payload = JSON.parse(String(event.data)) as {
              type: string;
              mine: boolean;
              message: { id: number; body: string; image: string | null; created_at: string };
            };
            if (payload.type !== 'message') return;
            absorb([{ ...payload.message, mine: payload.mine, read: false }]);
          } catch { /* 알 수 없는 형식은 버린다 */ }
        };
        ws.onerror = () => { /* onclose 가 뒤따르므로 거기서 한 번만 처리한다 */ };
        ws.onclose = () => {
          if (!alive) return;
          setState((p) => ({ ...p, connected: false }));
          socket.current = null;
          startPolling(true); // 끊기면 되묻기로 이어 간다
        };
      } catch {
        if (alive) {
          setState((p) => ({ ...p, loaded: true, error: 'Could not reach the conversation.' }));
          startPolling(otherKind === 'user');
        }
      }
    })();

    return () => {
      alive = false;
      if (poll) clearTimeout(poll);
      ws?.close();
      socket.current = null;
    };
  }, [thread, otherKind, absorb]);

  /**
   * 보내기 — 사진이 붙으면 업로드가 필요해 HTTP 로 간다.
   * 소켓이 열려 있으면 글은 소켓으로: 서버가 저장하고 그 자리에서 양쪽에 돌려준다.
   */
  const send = useCallback(async (toHandle: string, body: string, photoUri?: string | null) => {
    const ws = socket.current;
    if (!photoUri && ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ body }));
      return;
    }
    await sendDm(toHandle, body, photoUri);
    // 사진은 HTTP 로 갔으니 방금 것을 한 번 당겨 온다
    const data = await fetchThread(thread, lastId.current);
    absorb(data.messages);
  }, [thread, absorb]);

  return { ...state, send };
}
