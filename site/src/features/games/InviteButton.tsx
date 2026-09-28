'use client';
import { useEffect, useState } from 'react';
import { Button, Input } from '@/components/ui';

/**
 * 누군가를 이 게임으로 부른다 — 받는 쪽은 알림(팔로우·댓글과 같은 자리)에서 보고 링크로 내 옆에서 시작한다.
 * 빠른 선택: 내가 팔로우하는 사람 + 최근에 나를 부른 사람(GET /api/invite). 그 밖에는 핸들을 적는다.
 */
export function InviteButton({ game }: { game: string }) {
  const [open, setOpen] = useState(false);
  const [people, setPeople] = useState<{ handle: string }[]>([]);
  const [handle, setHandle] = useState('');
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!open) return;
    let alive = true;
    fetch('/api/invite').then(async (r) => (r.ok ? ((await r.json()) as { people: { handle: string }[] }) : { people: [] })).then((d) => { if (alive) setPeople(d.people); }).catch(() => {});
    return () => { alive = false; };
  }, [open]);
  const send = async (to: string) => {
    if (!to.trim() || busy) return;
    setBusy(true); setMsg('');
    const res = await fetch('/api/invite', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ to: to.trim(), game }) });
    const j = (await res.json().catch(() => ({}))) as { message?: string; already?: boolean };
    setBusy(false);
    if (!res.ok) { setMsg(j.message ?? 'Could not send that.'); return; }
    setMsg(j.already ? `${to.trim()} already has your invitation.` : `Invited ${to.trim()}. They will see it in their notifications.`); setHandle('');
  };
  return (
    <div className="relative">
      <Button variant="ghost" onClick={() => setOpen((o) => !o)} aria-expanded={open}>Invite someone</Button>
      {open && (
        <div className="absolute right-0 z-20 mt-2 w-[280px] rounded-xl border border-hairline bg-paper p-3 shadow-sm">
          <p className="font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft">Bring someone here</p>
          {people.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {people.slice(0, 12).map((p) => <button key={p.handle} type="button" onClick={() => send(p.handle)} disabled={busy} className="rounded-full border border-hairline px-2.5 py-1 text-[12px] font-bold hover:border-ink">{p.handle}</button>)}
            </div>
          )}
          <form className="mt-2 flex gap-1.5" onSubmit={(e) => { e.preventDefault(); void send(handle); }}>
            <Input value={handle} onChange={(e) => setHandle(e.target.value)} placeholder="handle" maxLength={40} aria-label="Handle to invite" />
            <Button type="submit" disabled={busy || handle.trim().length < 2}>Send</Button>
          </form>
          {msg && <p className="mt-2 text-[12.5px] text-accent-deep">{msg}</p>}
        </div>
      )}
    </div>
  );
}
