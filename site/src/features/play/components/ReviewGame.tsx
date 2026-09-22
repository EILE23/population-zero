'use client';
import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Button, Textarea } from '@/components/ui';

/**
 * 만든 사람의 검수 — 해 보고 공개하거나, 무엇이 잘못됐는지 적어 수정을 요청한다.
 * 문구는 버튼이 실제로 하는 일을 말한다(2026-09-22 카피 리뷰): "고친다" 가 아니라 "수정 요청이 큐에 들어간다",
 * 공개된 게임에 수정을 요청하면 다음 버전을 시험할 때까지 **비공개로 내려간다** — 그 결과를 버튼 옆에 미리 적는다.
 */
export function ReviewGame({ slug, title, live }: { slug: string; title: string; live: boolean }) {
  const router = useRouter();
  const [note, setNote] = useState(''); const [busy, setBusy] = useState(false); const [msg, setMsg] = useState('');
  const send = async (ok: boolean) => {
    setBusy(true); setMsg('');
    const res = await fetch(`/api/games/${slug}/review`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(ok ? { ok: true } : { note }) });
    const j = (await res.json().catch(() => ({}))) as { message?: string; status?: string };
    setBusy(false);
    if (!res.ok) { setMsg(j.message ?? 'Could not do that.'); return; }
    setMsg(ok ? 'Published. It is on the playground.' : 'Your changes are queued. You’ll be able to test the next version before publishing.'); setNote(''); router.refresh();
  };
  return (
    <div className="rounded-xl border border-accent/40 bg-paper p-4">
      <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-accent-deep">{live ? 'Your game' : 'Your game is ready to test'}</p>
      <p className="mt-1 text-[13.5px]"><Link href={`/play/${slug}`} className="font-bold underline underline-offset-2">{title}</Link>{live ? ' is on the playground. Something wrong with it? Describe it and request changes.' : ' is ready for you to test. This game isn’t public yet.'}</p>
      <div className="mt-3 grid gap-2">
        <Textarea value={note} onChange={(e) => setNote(e.target.value)} rows={2} maxLength={600} placeholder="What is wrong? e.g. the ball just bounces at the top, nobody hits it." />
        <div className="flex flex-wrap items-center gap-2">
          {!live && <Button onClick={() => send(true)} disabled={busy}>Publish game</Button>}
          <Button variant="ghost" onClick={() => send(false)} disabled={busy || note.trim().length < 8}>Request changes</Button>
          {live && <span className="text-[12px] text-ink-soft">Requesting changes will temporarily unpublish your game.</span>}
        </div>
        {msg && <p className="text-[13px] text-accent-deep">{msg}</p>}
      </div>
    </div>
  );
}
