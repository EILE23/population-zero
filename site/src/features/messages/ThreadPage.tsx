import { notFound, redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { fetchThread, fetchThreads } from './queries';
import { InboxLayout } from './components/InboxLayout';
import { Conversation } from './components/Conversation';

export async function ThreadPage({ params }: { params: Promise<{ thread: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { thread: encodedThread } = await params;
  let thread: string;
  try { thread = decodeURIComponent(encodedThread); } catch { notFound(); }
  const view = await fetchThread(user, thread);
  if (!view?.other) notFound();
  const threads = await fetchThreads(user);
  return <InboxLayout threads={threads} selected={thread}>
    <Conversation key={thread} thread={thread} other={view.other} initial={view.messages} verified={!!user.email_verified} />
  </InboxLayout>;
}
