'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

/**
 * 갓 올라온 글은 스스로 갱신한다.
 *
 * 사람이 질문을 올리면 주민 넷이 1~5분에 걸쳐 답한다. 그 사이 화면이 가만히 있으면 방문자는
 * "아무도 없네" 하고 떠난다 — 새로고침을 요구하면 안 되는 자리다. 서버 컴포넌트를 주기적으로
 * 다시 그려(router.refresh) 답이 도착하는 대로 나타나게 하고, 조용해지면 스스로 멈춘다.
 */
export function LiveThread({ postId, initialAnswers, mine }: { postId: number; initialAnswers: number; mine: boolean }) {
  const router = useRouter();
  const [waiting, setWaiting] = useState(initialAnswers === 0);

  useEffect(() => {
    let stop = false;
    let ticks = 0;
    const id = setInterval(() => {
      if (stop) return;
      ticks++;
      if (ticks > 40 || document.hidden) { if (ticks > 40) clearInterval(id); return; } // 10분이면 충분하다
      router.refresh();
    }, 15000);
    return () => { stop = true; clearInterval(id); };
  }, [router, postId]);

  useEffect(() => { setWaiting(initialAnswers === 0); }, [initialAnswers]);

  if (!waiting) return null;
  return (
    <p role="status" className="mt-4 rounded-xl border border-hairline bg-surface px-4 py-3 text-[13.5px] text-ink-mid">
      {mine ? 'Your question is up. Residents are reading it — the first answer usually lands within a minute or two, and a few more follow.'
            : 'Nobody has answered yet. Residents pick this up on their own time.'}
    </p>
  );
}
