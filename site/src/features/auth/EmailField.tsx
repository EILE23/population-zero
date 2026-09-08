'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';

type Status = 'idle' | 'checking' | 'ok' | 'taken' | 'invalid';

/** 이메일 입력 + 실시간 중복검사 — 오류는 배너가 아니라 인풋 바로 아래에서.
 *  taken/invalid 이면 setCustomValidity 로 제출을 막는다 (ValidatedForm 이 흔들며 강조). */
export function EmailField({ initialTaken = false }: { initialTaken?: boolean }) {
  const [value, setValue] = useState('');
  const [status, setStatus] = useState<Status>(initialTaken ? 'taken' : 'idle');
  const [takenKind, setTakenKind] = useState<'google' | 'local' | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (timer.current) clearTimeout(timer.current);
    const e = value.trim().toLowerCase();
    if (!e) { setStatus(initialTaken && !value ? 'taken' : 'idle'); return; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e)) { setStatus('idle'); return; } // 타이핑 중엔 조용히
    setStatus('checking');
    timer.current = setTimeout(async () => {
      try {
        const res = await fetch(`/api/auth/email-check?e=${encodeURIComponent(e)}`);
        const d = (await res.json()) as { available: boolean; kind?: 'google' | 'local' | null };
        setStatus(d.available ? 'ok' : 'taken');
        setTakenKind(d.available ? null : (d.kind ?? null));
      } catch { setStatus('idle'); }
    }, 450);
    return () => { if (timer.current) clearTimeout(timer.current); };
  }, [value, initialTaken]);

  const bad = status === 'taken';
  useEffect(() => { input.current?.setCustomValidity(bad ? 'taken' : ''); }, [bad]);

  return (
    <div className="mt-2" data-self-hint>
      <input
        ref={input}
        name="email" type="email" maxLength={254} required placeholder="email (we'll send a verification link)" autoComplete="email"
        value={value} onChange={(e) => setValue(e.target.value)}
        aria-invalid={bad}
        className="w-full rounded-lg border border-hairline bg-paper px-3.5 py-2.5 text-[14.5px] outline-none focus:border-ink aria-invalid:border-ink"
      />
      {status === 'taken' && (
        <div role="alert" className="mt-1 text-[12px] font-bold text-ink">
          {takenKind === 'google'
            ? <>✗ this email is registered via Google — use “Continue with Google” above</>
            : <>✗ already registered — <Link className="underline underline-offset-2" href="/login">log in instead</Link></>}
        </div>
      )}
      {status === 'ok' && <div className="mt-1 text-[12px] font-semibold text-ink">✓ looks good</div>}
      {status === 'checking' && <div className="mt-1 text-[12px] font-semibold text-ink-soft">checking…</div>}
    </div>
  );
}
