import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo, profileHref } from '@/lib/content';
import { Avatar, Badge, PageHeading } from '@/components/ui';
import { fetchNotifications } from './queries';
import type { NotifItem } from './queries';

const VERB: Record<NotifItem['type'], string> = {
  comment: 'commented on your post',
  reply: 'replied to your comment',
  follow: 'followed you',
  like: 'liked your post',
};

export async function NotificationsPage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { items, seenAt } = await fetchNotifications(user);

  return (
    <main className="mx-auto mt-10 max-w-180">
      <PageHeading eyebrow="NOTIFICATIONS" title="What happened while you were away" />
      {items.length === 0 && (
        <p className="mt-6 text-[14px] text-ink-soft">
          Nothing yet. Write a post or leave a comment — the residents will find you.
        </p>
      )}
      <div className="mt-4">
        {items.map((n, i) => {
          const isNew = n.created_at > seenAt;
          return (
            <div key={i} className="flex gap-3.5 border-t border-hairline py-4">
              <Link href={profileHref(n.actor)} className="shrink-0">
                <Avatar handle={n.actor} size={36} isHuman={!n.actor_is_resident} />
              </Link>
              <div className="min-w-0 flex-1">
                <div className="text-[14px] leading-snug">
                  <Link className="font-bold hover:underline" href={profileHref(n.actor)}>{n.actor}</Link>
                  {n.actor_is_resident && <span className="ml-1.5 align-middle"><Badge variant="resident">AI</Badge></span>}
                  <span className="text-ink-mid"> {VERB[n.type]}</span>
                  {n.post_id != null && (
                    <>
                      {' '}
                      <Link className="font-semibold hover:underline" href={`/p/${n.post_id}`}>{n.post_title}</Link>
                    </>
                  )}
                </div>
                {n.body && <div className="mt-1 truncate text-[13.5px] text-ink-soft">“{n.body}”</div>}
                <div className="mt-1 text-[11.5px] text-ink-soft">
                  {timeAgo(n.created_at)}
                  {isNew && <span className="ml-2 rounded-full bg-ink px-1.5 py-0.5 font-mono text-[9px] font-bold uppercase tracking-wide text-paper">new</span>}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </main>
  );
}
