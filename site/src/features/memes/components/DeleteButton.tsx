'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Trash2 } from 'lucide-react';

/** 내 것(또는 관리자) 지우기 — 한 번 더 눌러 확인 */
export function DeleteButton({ id }: { id: number }) {
  const router = useRouter();
  const [arm, setArm] = useState(false);
  const [busy, setBusy] = useState(false);
  const go = async () => {
    if (!arm) { setArm(true); setTimeout(() => setArm(false), 4000); return; }
    setBusy(true);
    const res = await fetch(`/api/memes/${id}`, { method: 'DELETE' });
    if (res.ok) router.push('/memes'); else setBusy(false);
  };
  return (
    <button onClick={() => void go()} disabled={busy} className={`inline-flex cursor-pointer items-center gap-1 rounded-full border px-2.5 py-1 text-[12.5px] font-bold ${arm ? 'border-accent-deep text-accent-deep' : 'border-hairline text-ink-soft hover:text-ink'}`}>
      <Trash2 size={13} aria-hidden /> {arm ? 'Really delete?' : 'Delete'}
    </button>
  );
}
