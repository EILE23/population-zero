'use client';
import { useState } from 'react';
import { SubmitButton } from '@/components/SubmitButton';

/** 방명록 한 줄 — 로그인 안 했으면 가입 뒤 이 블로그로 돌아온다(pz_next) */
export function GuestbookForm({ handle, canWrite }: { handle: string; canWrite: boolean }) {
  const [body, setBody] = useState('');
  const [state, setState] = useState<'idle' | 'sent' | 'fail'>('idle');
  const [message, setMessage] = useState('');

  if (!canWrite) {
    return (
      <p className="mt-4 text-[13px] text-ink-soft">
        <a
          href="/login?mode=signup"
          onClick={() => { document.cookie = `pz_next=${encodeURIComponent(`/@${handle}`)}; path=/; max-age=900; samesite=lax`; }}
          className="font-semibold underline underline-offset-2 hover:text-ink"
        >
          Log in
        </a>{' '}to leave a note.
      </p>
    );
  }

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const text = body.trim();
    if (text.length < 2) return;
    const res = await fetch('/api/guestbook', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ handle, body: text }),
    });
    if (!res.ok) {
      const d = await res.json().catch(() => ({})) as { message?: string };
      setState('fail'); setMessage(d.message ?? 'Could not post that.');
      return;
    }
    setBody(''); setState('sent');
    location.reload(); // 방명록은 서버가 그린다 — 새로 그려서 방금 쓴 줄을 보여준다
  }

  return (
    <form onSubmit={send} className="mt-4">
      <textarea
        value={body}
        onChange={(e) => setBody(e.target.value)}
        rows={2}
        maxLength={600}
        placeholder="Leave a note"
        className="w-full rounded-lg border border-hairline bg-paper px-3 py-2 text-[14px] outline-none focus:border-ink"
      />
      <div className="mt-2 flex items-center gap-3">
        <SubmitButton variant="primary" pendingLabel="Signing…" disabled={body.trim().length < 2}>Sign</SubmitButton>
        {state === 'fail' && <span role="alert" className="text-[13px] font-semibold text-accent-deep">{message}</span>}
      </div>
    </form>
  );
}
