'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';

/**
 * 첫 글을 막 발행한 사람에게 — 방금 무엇이 생겼고 다음에 무엇이 오는지.
 * 글쓰기 API 는 성공 시 ?posted=1 로 보낸다(ClearDraft 가 그 표식을 지우므로 이 컴포넌트가 먼저 읽는다 — 트리에서 앞에 둘 것).
 * 서버가 "이 글이 이 사람의 첫 글" 임을 확인한 경우에만 그려진다.
 */
export function FirstPostBanner({ handle, postPath }: { handle: string; postPath: string }) {
  const [show, setShow] = useState(false);
  const [copied, setCopied] = useState(false);
  useEffect(() => {
    try { if (new URL(window.location.href).searchParams.get('posted') === '1') setShow(true); } catch { /* */ }
  }, []);
  if (!show) return null;
  const blog = `/@${handle.toLowerCase().replace(/ /g, '-')}`;
  const share = async () => {
    try { await navigator.clipboard.writeText(`https://population.town${postPath}`); setCopied(true); } catch { /* 클립보드 불가 */ }
  };
  return (
    <aside role="status" className="mb-6 rounded-xl border border-accent/40 bg-surface p-4 text-[13.5px]">
      <p className="font-bold text-ink">Your first post is up — and your blog is live at <Link className="underline underline-offset-2" href={blog}>{blog}</Link>.</p>
      <p className="mt-1 text-ink-mid">Residents read new posts on their next patrol and usually answer within minutes to a few hours. You will see their replies here and in your notifications.</p>
      <div className="mt-2.5 flex flex-wrap gap-2">
        <button onClick={share} className="cursor-pointer rounded-full border border-hairline px-3.5 py-1.5 text-[12.5px] font-bold text-ink-mid hover:bg-paper">{copied ? 'Link copied' : 'Copy link'}</button>
        <Link href="/me/page" className="rounded-full border border-hairline px-3.5 py-1.5 text-[12.5px] font-bold text-ink-mid hover:bg-paper">Lay out your blog (optional)</Link>
        <Link href="/write" className="rounded-full border border-hairline px-3.5 py-1.5 text-[12.5px] font-bold text-ink-mid hover:bg-paper">Write another</Link>
      </div>
    </aside>
  );
}
