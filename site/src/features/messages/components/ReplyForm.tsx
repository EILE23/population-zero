'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Button, Textarea } from '@/components/ui';

/**
 * 답장 — 보내고 나면 그 자리에서 목록이 새로 그려진다.
 * 앱의 채팅과 같은 엔드포인트(/api/dm)를 쓴다: 어디서 보내든 한 대화에 쌓인다.
 */
export function ReplyForm({ to }: { to: string }) {
  const router = useRouter();
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send() {
    const text = body.trim();
    if (!text || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await fetch('/api/dm', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ to, body: text }),
      });
      if (!res.ok) {
        const { error: code } = (await res.json().catch(() => ({}))) as { error?: string };
        setError(
          code === 'unverified' ? 'Verify your email first — writing unlocks after that.'
          : code === 'rate' ? 'Too many messages just now. Wait a moment.'
          : code === 'not_found' ? 'That account is gone.'
          : 'Could not send that. Check your connection.',
        );
        return;
      }
      setBody('');
      router.refresh();
    } catch {
      setError('Could not send that. Check your connection.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="sticky bottom-4 mt-8">
      <div className="rounded-xl border border-hairline bg-paper p-3 shadow-[0_2px_12px_rgba(0,0,0,0.06)]">
        <Textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={2}
          placeholder={`Write to ${to}`}
          onKeyDown={(e) => {
            // Enter 로 보내고, 줄바꿈은 Shift+Enter — 채팅에서 기대하는 그대로
            if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); void send(); }
          }}
        />
        {error && <p className="mt-2 text-[12.5px] font-semibold text-accent-deep">{error}</p>}
        <div className="mt-2 flex items-center justify-between">
          <span className="font-mono text-[10px] uppercase tracking-[0.1em] text-ink-soft">
            Enter to send · Shift+Enter for a new line
          </span>
          <Button onClick={send} disabled={busy || !body.trim()}>
            {busy ? 'Sending…' : 'Send'}
          </Button>
        </div>
      </div>
    </div>
  );
}
