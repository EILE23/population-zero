'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';

/**
 * POZ 실행 — "Play" 를 누르면 로그인한 사람에겐 게임 입장권(/api/game/token)을 받아 iframe 의 게임에 postMessage 로 건넨다(URL 에 싣지 않는다).
 * 게임은 준비되면 { poz: 'hello' } 를 보내고, 여기서 { poz: 'token', token, handle } 로 답한다. 로그인하지 않았으면 구경꾼으로 들어간다.
 * 시작하면 키 입력이 바로 게임으로 가게 iframe 에 포커스, 전체 화면 단추(2026-10-06).
 */
const GAME_URL = 'https://eile23.github.io/population-zero/';
const GAME_ORIGIN = 'https://eile23.github.io';

type Ticket = { token: string; handle: string } | null;

export function PozFrame({ handle }: { handle: string | null }) {
  const [started, setStarted] = useState(false);
  const [ticket, setTicket] = useState<Ticket>(null);
  const [note, setNote] = useState('');
  const frame = useRef<HTMLIFrameElement>(null);
  const box = useRef<HTMLDivElement>(null);

  async function play() {
    setStarted(true);
    if (!handle) {
      setNote('Watching as a guest.');
      return;
    }
    try {
      const r = await fetch('/api/game/token', { credentials: 'same-origin', cache: 'no-store' });
      if (r.ok) {
        const j = (await r.json()) as { token: string; user: { handle: string } };
        setTicket({ token: j.token, handle: j.user.handle });
        setNote(`Playing as ${j.user.handle}. Coins and records are saved to your account.`);
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

  function fullscreen() {
    void box.current?.requestFullscreen?.();
    frame.current?.focus();
  }

  if (!started) {
    return (
      <div className="mt-4 flex aspect-[960/470] w-full flex-col items-center justify-center gap-4 rounded-xl border border-hairline bg-paper px-4 text-center">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">The town · Climb · Racing</p>
        <button type="button" onClick={play} className="rounded-full border-2 border-ink px-9 py-3 font-mono text-[15px] font-bold uppercase tracking-[0.16em] text-ink hover:bg-ink hover:text-paper">Play</button>
        {handle ? (
          <p className="text-[13px] text-ink-mid">Playing as <span className="font-bold text-ink">{handle}</span>. Coins and records are saved.</p>
        ) : (
          <p className="text-[13px] text-ink-mid">
            <Link href="/login" className="font-bold text-accent underline underline-offset-2">Log in</Link> to play as yourself, chat and keep your coins. Or press Play to watch.
          </p>
        )}
        <p className="text-[11.5px] text-ink-soft">Desktop and keyboard. The first load is a few tens of megabytes; it is cached after that.</p>
      </div>
    );
  }
  return (
    <>
      <div ref={box} className="mt-4 w-full overflow-hidden rounded-xl border border-hairline bg-paper">
        <iframe ref={frame} src={GAME_URL} title="POZ" className="block aspect-[960/470] h-full w-full" allow="autoplay; fullscreen; gamepad" loading="eager" onLoad={() => frame.current?.focus()} />
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-3 text-[12px] text-ink-soft">
        <span>{note}</span>
        <button type="button" onClick={fullscreen} className="ml-auto font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-ink hover:text-accent">Full screen</button>
      </div>
    </>
  );
}
