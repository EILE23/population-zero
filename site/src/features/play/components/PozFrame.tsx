'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * POZ 실행 — "Play" 를 누르면 로그인한 사람에겐 게임 입장권(/api/game/token)을 받아 iframe 의 게임에 postMessage 로 건넨다(URL 에 싣지 않는다).
 * 게임은 준비되면 { poz: 'hello' } 를 보내고, 여기서 { poz: 'token', token, handle } 로 답한다. 로그인하지 않았으면 구경꾼으로 들어간다.
 */
const GAME_URL = 'https://eile23.github.io/population-zero/';
const GAME_ORIGIN = 'https://eile23.github.io';

type Ticket = { token: string; handle: string } | null;

export function PozFrame() {
  const [started, setStarted] = useState(false);
  const [ticket, setTicket] = useState<Ticket>(null);
  const [note, setNote] = useState('');
  const frame = useRef<HTMLIFrameElement>(null);

  async function play() {
    setStarted(true);
    try {
      const r = await fetch('/api/game/token', { credentials: 'same-origin', cache: 'no-store' });
      if (r.ok) {
        const j = (await r.json()) as { token: string; user: { handle: string } };
        setTicket({ token: j.token, handle: j.user.handle });
        setNote(`Playing as ${j.user.handle}.`);
      } else setNote('Watching as a guest. Log in to play as yourself.');
    } catch {
      setNote('Watching as a guest.');
    }
  }

  useEffect(() => {
    function onMessage(e: MessageEvent) {
      if (e.origin !== GAME_ORIGIN || !frame.current?.contentWindow) return;
      const d = e.data as { poz?: string } | null;
      if (d?.poz === 'hello') frame.current.contentWindow.postMessage(ticket ? { poz: 'token', token: ticket.token, handle: ticket.handle } : { poz: 'guest' }, GAME_ORIGIN);
    }
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [ticket]);

  if (!started) {
    return (
      <div className="mx-auto mt-4 flex aspect-[960/470] max-w-[960px] flex-col items-center justify-center gap-3 rounded-xl border border-hairline bg-paper">
        <button type="button" onClick={play} className="rounded-full border border-ink px-6 py-2 font-mono text-[13px] font-bold uppercase tracking-[0.14em] text-ink hover:bg-ink hover:text-paper">Play</button>
        <p className="text-[12px] text-ink-soft">Logged in: you play as yourself, your coins and records are saved. Otherwise you watch.</p>
      </div>
    );
  }
  return (
    <>
      <div className="mx-auto mt-4 max-w-[960px] overflow-hidden rounded-xl border border-hairline bg-paper">
        <iframe ref={frame} src={GAME_URL} title="POZ" className="block aspect-[960/470] w-full" allow="autoplay; fullscreen; gamepad" loading="eager" />
      </div>
      <p className="mx-auto mt-2 max-w-[960px] text-[12px] text-ink-soft">{note} First load is a few tens of megabytes; it is cached after that.</p>
    </>
  );
}
