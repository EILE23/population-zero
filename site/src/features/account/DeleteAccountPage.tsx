'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui';

/**
 * 계정 삭제 — 스토어 요건이자 약속: 두 단계(메일 요청 → 링크에서 확인), 확인 전엔 아무것도 지워지지 않는다.
 * 링크로 들어오면 URL 해시에 토큰이 있고, 그 순간 해시는 주소창에서 지운다(뒤로가기·공유에 남지 않게).
 */
export function DeleteAccountPage() {
  const [token, setToken] = useState('');
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<'requested' | 'deleted' | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    const t = location.hash.slice(1);
    if (t) { setToken(t); history.replaceState(null, '', location.pathname); }
  }, []);

  async function submit() {
    setBusy(true);
    setError('');
    try {
      const res = await fetch(token ? '/api/account/confirm-delete' : '/api/me/delete-account', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ token, confirm }),
      });
      const data = (await res.json().catch(() => ({}))) as { error?: string };
      if (!res.ok) throw new Error(data.error || 'Please try again.');
      setDone(token ? 'deleted' : 'requested');
      setToken('');
      setConfirm(false);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not connect.');
    } finally {
      setBusy(false);
    }
  }

  const confirming = token.length > 0;

  return (
    <main className="mx-auto mt-10 max-w-xl">
      <div className="font-mono text-[10.5px] font-bold uppercase tracking-widest text-ink-soft">Account</div>
      <h1 className="mt-2 font-display text-[32px] font-bold leading-tight tracking-tight">
        {confirming ? 'Confirm deletion' : 'Delete your account'}
      </h1>

      {done === 'deleted' ? (
        <div className="mt-6 rounded-xl border border-hairline bg-paper p-5">
          <p className="font-semibold">Your account is gone.</p>
          <p className="mt-2 text-[13.5px] leading-relaxed text-ink-mid">
            Posts, comments and messages were removed from the database. Uploaded files are queued and disappear within 30 days.
          </p>
          <Link href="/" className="mt-4 inline-block text-[13px] font-bold underline underline-offset-2">Back to the town</Link>
        </div>
      ) : done === 'requested' ? (
        <div className="mt-6 rounded-xl border border-hairline bg-paper p-5">
          <p className="font-semibold">Check your email.</p>
          <p className="mt-2 text-[13.5px] leading-relaxed text-ink-mid">
            We sent a confirmation link to your account address. It works for 30 minutes. Nothing is deleted until you open it and confirm.
          </p>
        </div>
      ) : (
        <>
          <p className="mt-4 text-[14.5px] leading-relaxed text-ink-mid">
            This permanently removes from POZ:
          </p>
          <ul className="mt-3 space-y-1.5 text-[14px] text-ink">
            <li className="flex gap-2.5"><span className="text-accent" aria-hidden>—</span> your account and profile</li>
            <li className="flex gap-2.5"><span className="text-accent" aria-hidden>—</span> every post and comment you wrote</li>
            <li className="flex gap-2.5"><span className="text-accent" aria-hidden>—</span> your messages, follows, likes and reports</li>
            <li className="flex gap-2.5"><span className="text-accent" aria-hidden>—</span> uploaded photos — removed within 30 days</li>
          </ul>
          <p className="mt-4 text-[13px] leading-relaxed text-ink-soft">
            Copies other people saved, search-engine caches and quotes in residents&apos; replies may remain. This cannot be undone.
          </p>

          <div className="mt-6 rounded-xl border border-hairline bg-paper p-5">
            {confirming ? (
              <label className="flex cursor-pointer items-start gap-3 text-[14px]">
                <input
                  type="checkbox"
                  checked={confirm}
                  onChange={(e) => setConfirm(e.target.checked)}
                  className="mt-0.5 size-4 accent-accent"
                />
                <span>I understand my account and everything I wrote will be deleted, and that this cannot be undone.</span>
              </label>
            ) : (
              <p className="text-[13.5px] leading-relaxed text-ink-mid">
                We email a confirmation link to your account address first. No link yet?{' '}
                <Link className="font-semibold text-ink underline underline-offset-2" href="/login">Sign in</Link> and request one here,
                or start from Settings in the app. Locked out? <Link className="font-semibold text-ink underline underline-offset-2" href="/contact">Contact support</Link>.
              </p>
            )}

            {error && <p role="alert" className="mt-3 text-[13px] font-semibold text-accent-deep">{error}</p>}

            <div className="mt-4 flex flex-wrap items-center gap-3">
              <Button
                variant={confirming ? 'primary' : 'ghost'}
                disabled={busy || (confirming && !confirm)}
                onClick={() => void submit()}
              >
                {busy ? 'Working…' : confirming ? 'Permanently delete my account' : 'Send confirmation email'}
              </Button>
              <Link href="/me" className="text-[13px] font-semibold text-ink-soft hover:text-ink">Keep my account</Link>
            </div>
          </div>
        </>
      )}
    </main>
  );
}
