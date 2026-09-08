'use client';
import { useState, type FormEvent, type ReactNode } from 'react';
import { FieldError } from '@/components/ui';
import { shakeElement } from '@/lib/shake';

// 제출 시점 검증 — 브라우저 기본 말풍선 대신, 첫 오류 필드를 흔들고 굵은 오류 문구를 붙인 뒤 제출을 막는다.
// 서버 라우트의 리다이렉트 오류(?error=)는 그대로 최후 방어선으로 남는다.
const LABEL: Record<string, string> = { handle: 'Handle', email: 'Email', password: 'Password', password2: 'Password confirmation' };
const RULE: Record<string, string> = {
  handle: 'Handle must be 3–20 characters: letters, numbers, - or _.',
  email: 'Enter a valid email address.',
  password: 'Password must be at least 8 characters.',
  password2: 'Passwords do not match — check both fields.',
};

function messageFor(el: HTMLInputElement): string {
  if (el.validity.valueMissing) return `${LABEL[el.name] ?? 'This field'} is required.`;
  return RULE[el.name] ?? el.validationMessage;
}

export function ValidatedForm({ action, className, children }: { action: string; className?: string; children: ReactNode }) {
  const [error, setError] = useState<string | null>(null);

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    const form = e.currentTarget;
    const p = form.elements.namedItem('password') as HTMLInputElement | null;
    const p2 = form.elements.namedItem('password2') as HTMLInputElement | null;
    if (p && p2) p2.setCustomValidity(p2.value && p2.value !== p.value ? 'mismatch' : '');
    if (form.checkValidity()) return;
    e.preventDefault();
    const bad = form.querySelector<HTMLInputElement>('input:invalid');
    if (!bad) return;
    const own = bad.closest<HTMLElement>('[data-self-hint]');
    if (own) shakeElement(own); // HandleField 처럼 자체 힌트가 있는 필드는 통째로 흔들고 문구는 그쪽 것을 쓴다
    else { bad.setAttribute('aria-invalid', 'true'); shakeElement(bad); setError(messageFor(bad)); }
    bad.focus();
  }

  function onInput(e: FormEvent<HTMLFormElement>) {
    const t = e.target as HTMLInputElement;
    if (t.name === 'password2') t.setCustomValidity('');
    if (!t.closest('[data-self-hint]')) t.removeAttribute('aria-invalid');
    setError(null);
  }

  return (
    <form method="post" action={action} className={className} noValidate onSubmit={onSubmit} onInput={onInput}>
      {children}
      {error && <FieldError>{error}</FieldError>}
    </form>
  );
}
