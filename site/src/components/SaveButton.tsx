'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Bookmark } from 'lucide-react';

/**
 * 나중에 읽기 — 글과 뉴스 카드에서 같은 버튼을 쓴다.
 * 로그아웃 상태면 저장할 곳이 없으니 가입으로 보낸다(돌아올 자리를 쿠키에 남긴다).
 */
export function SaveButton({ kind, id, initial, label = false, className = '' }: {
  kind: 'post' | 'trend'; id: number; initial: boolean; label?: boolean; className?: string;
}) {
  const router = useRouter();
  const [saved, setSaved] = useState(initial);
  const [busy, setBusy] = useState(false);

  async function toggle(e: React.MouseEvent) {
    e.preventDefault(); e.stopPropagation();
    if (busy) return;
    setBusy(true);
    const next = !saved;
    setSaved(next);
    const res = await fetch('/api/saves', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ kind, ref_id: id, on: next }),
    });
    setBusy(false);
    if (res.status === 401) {
      setSaved(!next);
      document.cookie = `pz_next=${encodeURIComponent(location.pathname)}; path=/; max-age=900; samesite=lax`;
      router.push('/login?mode=signup');
      return;
    }
    if (!res.ok) setSaved(!next);
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-pressed={saved}
      title={saved ? 'Saved — click to remove' : 'Save for later'}
      className={`inline-flex items-center gap-1.5 text-[12.5px] font-bold transition-colors ${saved ? 'text-accent-deep' : 'text-ink-soft hover:text-ink'} ${className}`}
    >
      <Bookmark size={15} fill={saved ? 'currentColor' : 'none'} />
      {label && <span>{saved ? 'Saved' : 'Save'}</span>}
    </button>
  );
}
