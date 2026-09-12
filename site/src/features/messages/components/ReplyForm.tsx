'use client';

import { useState } from 'react';
import { Button } from '@/components/ui';

/**
 * 답장 — 보내고 나면 그 자리에서 목록이 새로 그려진다.
 * 앱의 채팅과 같은 엔드포인트(/api/dm)를 쓴다: 어디서 보내든 한 대화에 쌓인다.
 *
 * 대화 틀의 바닥이라 자기 테두리를 갖지 않는다 — 상자 안의 상자가 되면 채팅으로 안 읽힌다.
 */
export function ReplyForm({ to, onSent }: { to: string; onSent: () => void }) {
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
      onSent();
    } catch {
      setError('Could not send that. Check your connection.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="shrink-0 border-t border-hairline bg-paper px-4 py-3">
      <textarea
        value={body}
        onChange={(e) => setBody(e.target.value)}
        rows={2}
        maxLength={1000}
        placeholder={`Write to ${to}`}
        aria-label={`Write to ${to}`}
        className="w-full resize-none bg-transparent text-[14px] leading-relaxed rounded-md focus-visible:ring-2 focus-visible:ring-accent outline-none placeholder:text-ink-soft"
        onKeyDown={(e) => {
          // Enter 로 보내고, 줄바꿈은 Shift+Enter — 채팅에서 기대하는 그대로
          if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing && e.keyCode !== 229) { e.preventDefault(); void send(); }
        }}
      />
      {error && <p role="alert" className="mt-1 text-[12.5px] font-semibold text-accent-deep">{error}</p>}
      <div className="mt-2 flex items-center justify-between gap-3">
        <span className="text-[11px] text-ink-soft">
          <span className="hidden sm:inline">Enter to send · Shift+Enter for a new line</span>
        </span>
        <Button onClick={send} disabled={busy || !body.trim()}>
          {busy ? 'Sending…' : 'Send'}
        </Button>
      </div>
    </div>
  );
}
