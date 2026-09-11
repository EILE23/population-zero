import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import { Avatar } from '@/components/ui';
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

  return (
    <main className="mx-auto mt-6 max-w-180 px-4">
      <div className="flex items-center gap-3">
        <Link href="/messages" className="text-[13px] font-semibold text-ink-soft hover:text-ink">← Messages</Link>
      </div>

      <div className="mt-4 flex items-center gap-3 rounded-xl border border-hairline bg-paper px-4 py-3">
        <Avatar handle={other.handle} size={40} isHuman={other.kind === 'user'} src={other.avatar} />
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <Link href={`/@${other.handle}`} className="truncate font-display text-[16px] font-bold hover:underline">
              {other.handle}
            </Link>
            {other.kind === 'resident' && (
              <span className="font-mono text-[10px] font-bold tracking-[0.08em] text-accent">AI</span>
            )}
          </div>
          <div className="font-mono text-[10px] uppercase tracking-[0.1em] text-ink-soft">
            {other.kind === 'resident' ? 'Answers on the next patrol' : 'A person in the town'}
          </div>
        </div>
      </div>

      <ol className="mt-6 space-y-3">
        {messages.map((m) => (
          <li key={m.id} className={m.mine ? 'flex justify-end' : 'flex justify-start'}>
            <div className="max-w-[78%]">
              <div
                className={`overflow-hidden rounded-2xl ${
                  m.mine ? 'bg-accent text-paper' : 'border border-hairline bg-paper'
                }`}
              >
                {m.image && (
                  <img src={m.image} alt="" loading="lazy" className="block w-full max-w-90 object-cover" />
                )}
                {m.body && <p className="whitespace-pre-wrap px-4 py-2.5 text-[14px] leading-relaxed">{m.body}</p>}
              </div>
              <div className={`mt-1 font-mono text-[10px] text-ink-faint ${m.mine ? 'text-right' : ''}`}>
                {timeAgo(m.created_at)}{m.mine && m.read ? ' · read' : ''}
              </div>
            </div>
          </li>
        ))}
      </ol>

      {messages.length === 0 && (
        <p className="mt-10 text-center text-[13px] text-ink-soft">Nothing said yet. Start it.</p>
      )}

      <ReplyForm to={other.handle} />
    </main>
  );
}
