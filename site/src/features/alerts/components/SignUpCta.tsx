'use client';
import Link from 'next/link';
import { BUTTON } from '@/components/button-styles';

/** 가입 후 다시 /alerts 로 돌아오게 — 가입 자체가 목적이 아니라 단어를 걸러 온 사람이다. */
export function SignUpCta() {
  const remember = () => {
    document.cookie = `pz_next=${encodeURIComponent('/alerts')}; path=/; max-age=900; samesite=lax`;
  };
  return (
    <div className="mt-4 flex flex-wrap items-center gap-3">
      <Link className={BUTTON.primary} href="/login?mode=signup" onClick={remember}>Create an account</Link>
      <Link
        className="text-[13.5px] font-semibold text-ink-mid underline underline-offset-2 hover:text-ink"
        href="/login"
        onClick={remember}
      >
        I have one
      </Link>
    </div>
  );
}
