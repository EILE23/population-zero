'use client';
import { useEffect, useRef, useState } from 'react';

/** 핸들 입력 + 실시간 중복검사 (디바운스 400ms) — 가입·닉네임 변경 폼 공용 */
export function HandleField({ defaultValue = '', placeholder = 'handle (e.g. curious_dave)' }: { defaultValue?: string; placeholder?: string }) {
  const [value, setValue] = useState(defaultValue);
  const [status, setStatus] = useState<'idle' | 'checking' | 'ok' | 'taken' | 'invalid'>('idle');
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (timer.current) clearTimeout(timer.current);
    const h = value.trim();
    if (!h || h === defaultValue) { setStatus('idle'); return; }
    if (!/^[A-Za-z0-9_-]{3,20}$/.test(h)) { setStatus('invalid'); return; }
    setStatus('checking');
    timer.current = setTimeout(async () => {
      try {
        const res = await fetch(`/api/auth/handle-check?h=${encodeURIComponent(h)}`);
        const d = (await res.json()) as { available: boolean };
        setStatus(d.available ? 'ok' : 'taken');
      } catch { setStatus('idle'); }
    }, 400);
    return () => { if (timer.current) clearTimeout(timer.current); };
  }, [value, defaultValue]);

  const HINT: Record<typeof status, [string, string]> = {
    idle: ['', 'text-ink-soft'],
    checking: ['checking…', 'text-ink-soft'],
    ok: ['✓ available', 'text-ink'],
    taken: ['✗ already taken', 'text-ink'],
    invalid: ['3–20 chars: letters, numbers, - or _', 'text-ink-soft'],
  };
  const [hint, cls] = HINT[status];

  return (
    <div className="mt-2">
      <input
        name="handle" maxLength={20} required placeholder={placeholder} autoComplete="username"
        value={value} onChange={(e) => setValue(e.target.value)}
        aria-invalid={status === 'taken' || status === 'invalid'}
        className="w-full rounded-lg border border-hairline bg-paper px-3.5 py-2.5 text-[14.5px] outline-none focus:border-ink"
      />
      {hint && <div className={`mt-1 text-[12px] font-semibold ${cls}`}>{hint}</div>}
    </div>
  );
}
