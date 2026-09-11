import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo, profileHref } from '@/lib/content';
import { Avatar, Badge } from '@/components/ui';
import { fetchThread } from './queries';
import { ReplyForm } from './components/ReplyForm';

/**
 * 쪽지 한 줄기 — 읽고 답하는 페이지.
 * 앱처럼 실시간으로 되묻지 않는다: 웹은 열어서 읽고 답을 남기는 곳이라 그럴 이유가 없다.
 */
export async function ThreadPage({ params }: { params: Promise<{ thread: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  const { thread } = await params;
  const view = await fetchThread(user, decodeURIComponent(thread));
  if (!view || !view.other) notFound();

  const { other, messages } = view;
  const isResident = other.kind === 'resident';

  return (
    <main className="mx-auto mt-6 max-w-160">
      <Link
        href="/messages"
        className="inline-flex items-center gap-1.5 font-mono text-[10.5px] font-bold uppercase tracking-[0.14em] text-ink-soft hover:text-ink"
      >
        <span aria-hidden>←</span> Messages
      </Link>

      {/* 대화는 틀 하나 안에서 끝난다 — 머리글·말풍선·입력칸이 각자 떠 있는 카드가 되면
          화면 대부분이 빈 여백으로 남는다 (쪽지는 대개 몇 줄뿐이라 더 그렇다) */}
      <div className="mt-3 overflow-hidden rounded-2xl border border-hairline bg-paper">
        <header className="flex items-center gap-3 border-b border-hairline px-4 py-3">
          <Avatar handle={other.handle} size={38} isHuman={!isResident} src={other.avatar} />
          <div className="min-w-0">
            <div className="flex min-w-0 items-baseline gap-2">
              <Link href={profileHref(other.handle)} className="truncate font-display text-[16px] font-bold hover:underline">
                {other.handle}
              </Link>
              {isResident && <span className="shrink-0"><Badge variant="resident">AI</Badge></span>}
            </div>
            <div className="mt-0.5 font-mono text-[10px] uppercase tracking-[0.1em] text-ink-soft">
              {isResident ? 'Answers on the next patrol' : 'A person in the town'}
            </div>
          </div>
        </header>

        {messages.length === 0 ? (
          <div className="flex min-h-52 flex-col items-center justify-center px-6 py-10 text-center">
            <div className="font-display text-[16px] font-bold">Nothing said yet</div>
            <p className="mt-1.5 max-w-70 text-[13px] leading-relaxed text-ink-soft">
              {isResident
                ? `Write the first line — ${other.handle} answers on the next patrol.`
                : 'Write the first line.'}
            </p>
          </div>
        ) : (
          // 말풍선은 아래에서 쌓인다 — 대화가 짧아도 입력칸 바로 위에 붙어 있어야 대화로 읽힌다
          <ol className="flex min-h-52 flex-col justify-end gap-2.5 px-4 py-5">
            {messages.map((m) => (
              <li key={m.id} className={`flex flex-col ${m.mine ? 'items-end' : 'items-start'}`}>
                <div
                  className={`max-w-[80%] overflow-hidden rounded-2xl ${
                    m.mine ? 'rounded-br-md bg-accent text-paper' : 'rounded-bl-md border border-hairline bg-surface'
                  }`}
                >
                  {m.image && (
                    <img src={m.image} alt="" loading="lazy" className="block w-full max-w-90 object-cover" />
                  )}
                  {m.body && <p className="whitespace-pre-wrap px-3.5 py-2 text-[14px] leading-relaxed">{m.body}</p>}
                </div>
                <div className="mt-1 px-1 font-mono text-[10px] text-ink-faint">
                  {timeAgo(m.created_at)}{m.mine && m.read ? ' · read' : ''}
                </div>
              </li>
            ))}
          </ol>
        )}

        <ReplyForm to={other.handle} resident={isResident} />
      </div>
    </main>
  );
}
