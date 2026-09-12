import { useCallback, useEffect, useRef, useState } from 'react';
import { API_BASE, fetchThread, getToken, sendDm, type DmMessage } from '@/api';

type State = {
  messages: DmMessage[];
  live: boolean;
  loaded: boolean;
  connected: boolean;
  error: string | null;
};

/** HTTP owns the ordered cursor. Sockets wake the reader sooner; polling also
 * catches uploads, web sends, and missed socket events while connected. */
export function useChat(thread: string, otherKind: 'user' | 'resident') {
  const [state, setState] = useState<State>({
    messages: [], live: otherKind === 'user', loaded: false, connected: false, error: null,
  });
  const refresh = useRef<(() => Promise<void>) | null>(null);

  useEffect(() => {
    let alive = true;
    let cursor = 0;
    let running: Promise<void> | null = null;
    let again = false;
    let poll: ReturnType<typeof setTimeout> | null = null;
    let ws: WebSocket | null = null;
    setState({ messages: [], live: otherKind === 'user', loaded: false, connected: false, error: null });

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
            const merged = new Map(prev.messages.map(m => [m.id, m]));
            for (const m of data.messages) merged.set(m.id, m);
            return { ...prev, messages: [...merged.values()].sort((a, b) => a.id - b.id),
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
      catch { if (alive) setState(p => ({ ...p, loaded: true, error: 'Could not reach the conversation.' })); }
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
            setState(p => ({ ...p, connected: true }));
            void sync().catch(() => {});
          };
          ws.onmessage = () => { if (alive) void sync().catch(() => {}); };
          ws.onerror = () => {}; // HTTP synchronization continues independently.
          ws.onclose = () => { if (alive) setState(p => ({ ...p, connected: false })); };
        } catch { /* HTTP synchronization remains available. */ }
      })();
    }
    return () => {
      alive = false;
      if (poll) clearTimeout(poll);
      ws?.close();
      if (refresh.current === sync) refresh.current = null;
    };
  }, [thread, otherKind]);

  const send = useCallback(async (toHandle: string, body: string, photoUri?: string | null) => {
    const sync = refresh.current;
    // Draft clearing waits for server persistence; 403/429/errors reach the caller.
    await sendDm(toHandle, body, photoUri);
    // A read failure after a successful write must not invite a duplicate send.
    if (sync && refresh.current === sync) void sync().catch(() => {});
  }, []);

  return { ...state, send };
}
