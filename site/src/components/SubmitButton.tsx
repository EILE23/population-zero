'use client';
import { useEffect, useRef, useState } from 'react';
import { BUTTON, type ButtonVariant } from './button-styles';

/** 서버 폼 제출 버튼 — 한 번 제출되면 응답이 올 때까지 잠긴다.
 *  모바일에서 탭이 두 번 먹거나 응답이 느려 다시 누르면 댓글·글이 두 개 생기던 문제를 막는다.
 *  폼 검증이 제출을 취소하면(ValidatedForm 등) 곧바로 잠금을 푼다. */
export function SubmitButton({
  variant = 'primary', className = '', children, pendingLabel, ...props
}: { variant?: ButtonVariant; className?: string; children: React.ReactNode; pendingLabel?: string }
  & Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'children'>) {
  const ref = useRef<HTMLButtonElement>(null);
  const locked = useRef(false);
  const [pending, setPending] = useState(false);

  useEffect(() => {
    const form = ref.current?.form;
    if (!form) return;
    const release = () => { locked.current = false; setPending(false); };
    const onSubmit = (e: SubmitEvent) => {
      if (locked.current) { e.preventDefault(); return; } // 두 번째 이후 제출은 버린다
      locked.current = true;
      setPending(true);
      // 검증 실패 등으로 제출이 취소됐으면 되돌린다 (React onSubmit 의 preventDefault 는 이 시점에 반영돼 있다)
      setTimeout(() => { if (e.defaultPrevented) release(); }, 0);
    };
    // 뒤로가기로 캐시된 페이지가 복원되면 잠금이 남아 있으면 안 된다
    const onPageShow = (e: PageTransitionEvent) => { if (e.persisted) release(); };
    form.addEventListener('submit', onSubmit);
    window.addEventListener('pageshow', onPageShow);
    return () => { form.removeEventListener('submit', onSubmit); window.removeEventListener('pageshow', onPageShow); };
  }, []);

  return (
    <button ref={ref} disabled={pending} className={`${BUTTON[variant]} disabled:cursor-default disabled:opacity-50 ${className}`} {...props}>
      {pending ? (pendingLabel ?? children) : children}
    </button>
  );
}
