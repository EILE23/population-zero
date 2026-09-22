'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Input, Textarea } from '@/components/ui';

/** 게임 만들기 — 제목·설명을 큐에 넣는다. 결과는 서버가 다시 그린다(router.refresh) */
export function MakeGame({ pending }: { pending: { slug: string; title: string; status: string } | null }) {
  const router = useRouter();
  const [title, setTitle] = useState(''); const [prompt, setPrompt] = useState('');
  const [busy, setBusy] = useState(false); const [msg, setMsg] = useState('');
  const submit = async () => {
    setBusy(true); setMsg('');
    const res = await fetch('/api/games', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ title, prompt }) });
    const j = (await res.json().catch(() => ({}))) as { ok?: boolean; slug?: string; ahead?: number; message?: string };
    setBusy(false);
    if (!res.ok) { setMsg(j.message ?? 'Could not queue it.'); return; }
    setMsg(`Queued as /play/${j.slug}. ${j.ahead ? `${j.ahead} ahead of you.` : 'You are next.'} The developer builds a few a day.`); setTitle(''); setPrompt(''); router.refresh();
  };
  if (pending) return <p className="text-[13.5px] text-ink-mid">Yours is in the queue: <b>{pending.title}</b> <span className="font-mono text-[11px] text-ink-soft">/play/{pending.slug} · {pending.status}</span>. One at a time; it will appear above when it is built.</p>;
  return (
    <div className="grid gap-3">
      <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={40} placeholder="Title (3–40 characters)" />
      <Textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} maxLength={900} rows={5} placeholder="Describe the game. What the player does, what the AI residents do, how it ends. Example: a duck race across the park pond; you steer one duck with the arrow keys, residents bet on the others from the bank and complain. 40–900 characters." />
      <div className="flex items-center gap-3">
        <Button onClick={submit} disabled={busy || title.trim().length < 3 || prompt.trim().length < 40}>{busy ? 'Queueing…' : 'Queue it'}</Button>
        <span className="font-mono text-[11px] text-ink-soft">{prompt.length}/900</span>
      </div>
      {msg && <p className="text-[13px] text-accent-deep">{msg}</p>}
    </div>
  );
}
