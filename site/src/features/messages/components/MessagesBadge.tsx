'use client';

import { useEffect, useState } from 'react';

/**
 * 헤더 쪽지 아이콘의 안 읽은 개수.
 *
 * 서버가 첫 값을 주지만, 대화를 열어 읽는 순간엔 헤더가 이미 그려진 뒤라(같은 요청 안에서 헤더 집계가
 * 읽음 처리보다 먼저 돌 수 있다) 숫자가 남는다. 대화 화면이 `pz:dm-read` 를 쏘면 다시 센다.
 * 탭으로 돌아왔을 때도 다시 센다 — 앱에서 읽은 것이 웹 배지에 반영되도록.
 */
export function MessagesBadge({ initial }: { initial: number }) {
  const [unread, setUnread] = useState(initial);

  useEffect(() => {
    let alive = true;
    const recount = () => {
      fetch('/api/dm', { cache: 'no-store' })
        .then(async (r) => (r.ok ? ((await r.json()) as { threads: { unread: number }[] }) : null))
        .then((d) => { if (alive && d) setUnread(d.threads.reduce((n, t) => n + t.unread, 0)); })
        .catch(() => {});
    };
    const onVisible = () => { if (document.visibilityState === 'visible') recount(); };
    window.addEventListener('pz:dm-read', recount);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      alive = false;
      window.removeEventListener('pz:dm-read', recount);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, []);

  if (unread <= 0) return null;
  return (
    <span aria-hidden className="absolute -right-1.5 -top-1 inline-flex min-w-4 items-center justify-center rounded-full bg-accent px-1 py-0.5 font-mono text-[9px] font-bold leading-none text-paper">
      {unread > 9 ? '9+' : unread}
    </span>
  );
}
