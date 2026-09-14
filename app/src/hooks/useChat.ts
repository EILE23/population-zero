import { useCallback, useEffect, useRef, useState } from 'react';
import { API_BASE, fetchThread, getToken, sendDm, type DmMessage } from '@/api';

type State = {
  messages: DmMessage[];
  live: boolean;
  loaded: boolean;
  connected: boolean;
  error: string | null;
};

/** 대화가 바뀌면 상태도 처음부터 — 어느 대화의 것인지 key 로 구분한다 */
type Keyed = State & { key: string };

function fresh(key: string, otherKind: 'user' | 'resident'): Keyed {
  return { key, messages: [], live: otherKind === 'user', loaded: false, connected: false, error: null };
}

/** HTTP owns the ordered cursor. Sockets wake the reader sooner; polling also
 * catches uploads, web sends, and missed socket events while connected. */
export function useChat(thread: string, otherKind: 'user' | 'resident') {
  const key = `${thread}|${otherKind}`;
  const [state, setState] = useState<Keyed>(() => fresh(key, otherKind));
  const refresh = useRef<(() => Promise<void>) | null>(null);

  useEffect(() => {
    let alive = true;
    let cursor = 0;
    let running: Promise<void> | null = null;
    let again = false;
    let poll: ReturnType<typeof setTimeout> | null = null;
    let ws: WebSocket | null = null;
    // 이전 대화의 상태 위에 덮어쓰지 않는다 — key 가 다르면 새로 시작한다.
    // (effect 안에서 바로 setState 로 비우면 한 프레임 이전 대화가 비치고, 린트도 막는다)
    const base = (prev: Keyed): Keyed => (prev.key === key ? prev : fresh(key, otherKind));

    const sync = (): Promise<void> => {
      again = true;
      if (running) return running;
      running = (async () => {
        while (alive && again) {
          again = false;
          const data = await fetchThread(thread, cursor);
          if (!alive) return;
          if (data.messages.length) cursor = data.messages[data.messages.length - 1].id;
          setState(prev => {
            const p = base(prev);
            const merged = new Map(p.messages.map(m => [m.id, m]));
            for (const m of data.messages) merged.set(m.id, m);
            return { ...p, messages: [...merged.values()].sort((a, b) => a.id - b.id),
              live: data.live, loaded: true, error: null };
          });
          // Drain every page. Socket IDs must never skip unread history.
          if (data.messages.length === 200) again = true;
        }
      })().finally(() => { running = null; });
      return running;
    };
    refresh.current = sync;
    const tick = async () => {
      try { await sync(); }
      catch { if (alive) setState(p => ({ ...base(p), loaded: true, error: 'Could not reach the conversation.' })); }
      if (alive) poll = setTimeout(tick, otherKind === 'user' ? 3000 : 20000);
    };
    void tick();

    if (otherKind === 'user') {
      void (async () => {
        try {
          const token = await getToken();
          if (!token || !alive) return;
          ws = new WebSocket(`${API_BASE.replace(/^http/, 'ws')}/ws/dm?thread=${encodeURIComponent(thread)}&token=${encodeURIComponent(token)}`);
          ws.onopen = () => {
            if (!alive) return;
            setState(p => ({ ...base(p), connected: true }));
            void sync().catch(() => {});
          };
          ws.onmessage = () => { if (alive) void sync().catch(() => {}); };
          ws.onerror = () => {}; // HTTP synchronization continues independently.
          ws.onclose = () => { if (alive) setState(p => ({ ...base(p), connected: false })); };
        } catch { /* HTTP synchronization remains available. */ }
      })();
    }
    return () => {
      alive = false;
      if (poll) clearTimeout(poll);
      ws?.close();
      if (refresh.current === sync) refresh.current = null;
    };
  }, [thread, otherKind, key]);

  const send = useCallback(async (toHandle: string, body: string, photoUri?: string | null) => {
    const sync = refresh.current;
    // Draft clearing waits for server persistence; 403/429/errors reach the caller.
    await sendDm(toHandle, body, photoUri);
    // A read failure after a successful write must not invite a duplicate send.
    if (sync && refresh.current === sync) void sync().catch(() => {});
  }, []);

  // 아직 이전 대화의 상태가 남아 있으면 비어 있는 것으로 보여준다
  const view: State = state.key === key ? state : fresh(key, otherKind);
  return { ...view, send };
}
