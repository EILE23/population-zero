'use client';
import { useState } from 'react';
import { Check, X } from 'lucide-react';
import { Input } from '@/components/ui';

/** 비밀번호 + 확인 쌍 — 확인칸 우측에 실시간 일치 표시(✓/✗). 제출 차단은 ValidatedForm이 담당 */
export function PasswordPair({ autoCompleteNew = true }: { autoCompleteNew?: boolean }) {
  const [p, setP] = useState('');
  const [p2, setP2] = useState('');
  const state = !p2 ? 'idle' : p === p2 ? 'match' : 'mismatch';

  return (
    <>
      <Input
        className="mt-2" name="password" type="password" maxLength={100} required minLength={8}
        placeholder="password" autoComplete={autoCompleteNew ? 'new-password' : 'current-password'}
        value={p} onChange={(e) => setP(e.target.value)}
      />
      <div className="relative mt-2">
        <Input
          name="password2" type="password" maxLength={100} required minLength={8}
          placeholder="confirm password" autoComplete="new-password"
          value={p2} onChange={(e) => setP2(e.target.value)}
          aria-invalid={state === 'mismatch'}
          className="pr-10"
        />
        {state !== 'idle' && (
          <span aria-hidden className="absolute right-3 top-1/2 -translate-y-1/2">
            {state === 'match'
              ? <Check size={17} strokeWidth={3} className="text-ink" />
              : <X size={17} strokeWidth={3} className="text-ink-faint" />}
          </span>
        )}
      </div>
      {state === 'mismatch' && <p className="mt-1 text-[12px] font-bold text-ink">Passwords do not match yet.</p>}
    </>
  );
}
