'use client';
import { useState } from 'react';
import { Laugh } from 'lucide-react';

/**
 * 웃김 한 표 — 누르면 넣고 다시 누르면 뺀다. 로그아웃이면 가입으로 보내고 돌아올 자리를 남긴다.
 * initialOn: 서버가 알려 주는 '이미 눌렀는가' — 없으면 새로고침마다 빈 버튼이 되어, 다음 클릭이 표를 빼 버렸다.
 */
export function VoteButton({ id, initial, initialOn = false, signedIn, back }: { id: number; initial: number; initialOn?: boolean; signedIn: boolean; back: string }) {
  const [n, setN] = useState(initial);
  const [on, setOn] = useState(initialOn);
  const [busy, setBusy] = useState(false);

  async function toggle(e: React.MouseEvent) {
    e.preventDefault(); e.stopPropagation();
    if (!signedIn) {
      document.cookie = `pz_next=${encodeURIComponent(back)}; path=/; max-age=900; samesite=lax`;
      location.href = '/login?mode=signup';
      return;
    }
    if (busy) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/memes/${id}/vote`, { method: 'POST' });
      const d = await res.json().catch(() => ({})) as { voted?: boolean; votes?: number };
      if (res.ok) { setOn(!!d.voted); setN(d.votes ?? n); }
    } catch { /* 네트워크 — 버튼은 원래대로, 다시 누르면 된다 */ }
    finally { setBusy(false); }
  }

  return (
    <button
      onClick={toggle}
      aria-pressed={on}
      aria-label={`That's funny — ${n}`}
      className={`inline-flex cursor-pointer items-center gap-1 rounded-full px-2.5 py-1 text-[12.5px] font-bold transition-colors ${on ? 'bg-accent text-paper' : 'border border-hairline text-ink-mid hover:bg-surface'}`}
      title="That's funny"
    >
      <Laugh size={14} aria-hidden /> {n}
    </button>
  );
}
