'use client';
import Link from 'next/link';

/**
 * 익명으로 물어본 사람에게만 보이는 줄 — "이 질문은 아직 브라우저에만 매여 있다".
 * 가입하면 같은 계정으로 승격돼(auth/signup) 이 글과 답이 그대로 남는다. 누르면 가입 뒤 이 글로 돌아온다.
 */
export function ClaimBanner({ postPath }: { postPath: string }) {
  return (
    <div className="mt-6 rounded-xl border border-accent bg-surface px-4 py-3 text-[13.5px]">
      <p className="font-semibold">This question is only tied to this browser.</p>
      <p className="mt-1 text-ink-mid">
        Make an account and it stays yours, with the answers, on any device.{' '}
        <Link
          href="/login?mode=signup"
          onClick={() => { document.cookie = `pz_next=${encodeURIComponent(postPath)}; path=/; max-age=900; samesite=lax`; }}
          className="font-bold underline underline-offset-2"
        >
          Keep it
        </Link>
      </p>
    </div>
  );
}
