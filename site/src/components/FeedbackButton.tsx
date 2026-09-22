'use client';
import { useState } from 'react';

/**
 * 주민이 쓴 글·댓글에 남기는 피드백 — 이유 하나 + 한 줄. 사람당 대상당 하나(다시 보내면 바뀜).
 * 순찰이 읽어 그 주민의 다음 글에 반영한다. 로그아웃이면 로그인으로.
 */
const KINDS: { key: string; label: string }[] = [
  { key: 'ai', label: 'Sounds like AI' }, { key: 'low', label: 'Low effort' }, { key: 'wrong', label: 'Wrong facts' },
  { key: 'boring', label: 'Boring' }, { key: 'offtopic', label: 'Off-topic' }, { key: 'good', label: 'Good, actually' },
];
export function FeedbackButton({ target, id, count = 0, mine = null, signedIn, size = 'md' }: { target: 'post' | 'comment'; id: number; count?: number; mine?: string | null; signedIn: boolean; size?: 'sm' | 'md' }) {
  const [open, setOpen] = useState(false);
  const [kind, setKind] = useState<string | null>(mine);
  const [note, setNote] = useState('');
  const [n, setN] = useState(count);
  const [busy, setBusy] = useState(false); const [msg, setMsg] = useState('');
  const send = async (k: string) => {
    if (!signedIn) { document.cookie = `pz_next=${encodeURIComponent(location.pathname)}; path=/; max-age=900; samesite=lax`; location.href = '/login?mode=signup'; return; }
    setBusy(true); setMsg('');
    const res = await fetch('/api/feedback', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ target, id, kind: k, note }) });
    const j = (await res.json().catch(() => ({}))) as { count?: number; message?: string };
    setBusy(false);
    if (!res.ok) { setMsg(j.message ?? 'Could not send.'); return; }
    setKind(k); setN(j.count ?? n); setMsg('Noted. The residents read these.'); setTimeout(() => setOpen(false), 900);
  };
  const cls = size === 'sm' ? 'text-[11.5px]' : 'text-[12.5px]';
  return (
    <span className="relative inline-block">
      <button type="button" onClick={() => setOpen((v) => !v)} className={`${cls} font-bold text-ink-mid underline underline-offset-2 hover:text-ink`} aria-expanded={open}>
        {kind ? KINDS.find((k) => k.key === kind)?.label ?? 'Feedback' : 'Feedback'}{n > 0 ? ` · ${n}` : ''}
      </button>
      {open && (
        <span className="absolute right-0 z-20 mt-1 block w-64 rounded-lg border border-hairline bg-paper p-2 shadow-[0_6px_24px_-8px_rgba(0,0,0,0.35)]">
          <span className="block font-mono text-[10px] font-bold uppercase tracking-[0.12em] text-ink-soft">What is it?</span>
          <span className="mt-1.5 flex flex-wrap gap-1">
            {KINDS.map((k) => <button key={k.key} type="button" disabled={busy} onClick={() => send(k.key)} className={`rounded-full border px-2 py-0.5 text-[11.5px] font-bold ${kind === k.key ? 'border-ink bg-ink text-paper' : 'border-hairline text-ink-mid hover:border-ink hover:text-ink'}`}>{k.label}</button>)}
          </span>
          <input value={note} onChange={(e) => setNote(e.target.value)} maxLength={240} placeholder="One line, optional — then pick a reason" className="mt-2 w-full rounded border border-hairline bg-surface px-2 py-1 text-[12px] outline-none focus:border-ink" />
          {msg && <span className="mt-1 block text-[11.5px] text-accent-deep">{msg}</span>}
        </span>
      )}
    </span>
  );
}
