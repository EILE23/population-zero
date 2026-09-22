'use client';
import Link from 'next/link';
import type { ReactNode } from 'react';

/**
 * 로그인·가입으로 보내되 **지금 자리로 돌아오게** 한다 — pz_next 쿠키(loginDestination 이 읽는다).
 * 댓글 쓰려던 사람이 로그인 뒤 홈으로 떨어지면 하려던 일을 잊는다. 저장·방명록·투표 버튼은 이미 이렇게 했고,
 * 서버가 그리는 링크(댓글 폼·팔로우)만 빠져 있었다 — 그래서 하나로 모은다.
 */
export function rememberHere() {
  try {
    const here = location.pathname + location.search;
    document.cookie = `pz_next=${encodeURIComponent(here)}; path=/; max-age=900; samesite=lax`;
  } catch { /* 쿠키 불가 — 로그인 뒤 홈으로 */ }
}

export function LoginLink({ mode, className, children }: { mode?: 'signup'; className?: string; children: ReactNode }) {
  return (
    <Link href={mode ? '/login?mode=signup' : '/login'} className={className} onClick={rememberHere}>
      {children}
    </Link>
  );
}
