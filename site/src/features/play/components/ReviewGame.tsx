'use client';
import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Button, Textarea } from '@/components/ui';

/** 만든 사람의 검수 — 해 보고 승인하거나, 무엇이 잘못됐는지 적어 고치러 보낸다 */
export function ReviewGame({ slug, title, live }: { slug: string; title: string; live: boolean }) {
  const router = useRouter();
  const [note, setNote] = useState(''); const [busy, setBusy] = useState(false); const [msg, setMsg] = useState('');
  const send = async (ok: boolean) => {
    setBusy(true); setMsg('');
    const res = await fetch(`/api/games/${slug}/review`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(ok ? { ok: true } : { note }) });
    const j = (await res.json().catch(() => ({}))) as { message?: string; status?: string };
    setBusy(false);
    if (!res.ok) { setMsg(j.message ?? 'Could not do that.'); return; }
    setMsg(ok ? 'It is on the playground.' : 'Sent back. It gets fixed in the next build round.'); setNote(''); router.refresh();
  };
  return (
    <div className="rounded-xl border border-accent/40 bg-paper p-4">
      <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-accent-deep">{live ? 'Your game' : 'Built — try it before it goes up'}</p>
      <p className="mt-1 text-[13.5px]"><Link href={`/play/${slug}`} className="font-bold underline underline-offset-2">{title}</Link>{live ? ' is on the playground. Something wrong with it? Say so and it gets fixed.' : ' is ready for you to try. Nobody else can see it yet.'}</p>
      <div className="mt-3 grid gap-2">
        <Textarea value={note} onChange={(e) => setNote(e.target.value)} rows={2} maxLength={600} placeholder="What is wrong? e.g. the ball just bounces at the top, nobody hits it." />
        <div className="flex flex-wrap gap-2">
          {!live && <Button onClick={() => send(true)} disabled={busy}>It works — put it up</Button>}
          <Button variant="ghost" onClick={() => send(false)} disabled={busy || note.trim().length < 8}>Not right — fix it</Button>
        </div>
        {msg && <p className="text-[13px] text-accent-deep">{msg}</p>}
      </div>
    </div>
  );
}
