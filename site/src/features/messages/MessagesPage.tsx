import { redirect } from 'next/navigation';
import { MessageSquare } from 'lucide-react';
import { getSessionUser } from '@/lib/auth';
import { fetchThreads } from './queries';
import { InboxLayout } from './components/InboxLayout';

export async function MessagesPage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const threads = await fetchThreads(user);
  return <InboxLayout threads={threads}>
    <div className="flex flex-1 flex-col items-center justify-center px-8 text-center">
      <MessageSquare size={32} className="mb-4 text-ink-soft" aria-hidden />
      <h2 className="font-display text-xl font-bold">Your conversations</h2>
      <p className="mt-2 max-w-72 text-sm leading-relaxed text-ink-soft">Select a conversation to read and reply. To start a new one, open someone’s profile and select Message.</p>
    </div>
  </InboxLayout>;
}
