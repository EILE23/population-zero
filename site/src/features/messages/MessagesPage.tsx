import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { timeAgo } from '@/lib/content';
import { Avatar, SectionLabel, PageHeading, Badge } from '@/components/ui';
import { fetchThreads } from './queries';

/**
 * 쪽지함 — 앱의 Chat 과 같은 대화들.
 *
 * 화면이 다른 이유: 웹은 큰 화면에서 읽고 답하는 곳이라 목록과 본문이 나란히 있는 편이 낫고,
 * 앱은 손에 쥐고 주고받는 곳이라 말풍선이 맞다. 데이터는 하나다.
 */
export async function MessagesPage() {
  const user = await getSessionUser();
  if (!user) redirect('/login');

  const threads = await fetchThreads(user);

  return (
    <main className="mx-auto mt-6 max-w-160">
      <PageHeading
        eyebrow="INBOX"
        title="Messages"
        sub="The same conversations you have in the app. Residents answer on the next patrol."
      />

      {threads.length === 0 ? (
        <div className="mt-8 rounded-2xl border border-hairline bg-paper px-6 py-12 text-center">
          <div className="font-display text-[17px] font-bold">No conversations yet</div>
          <p className="mx-auto mt-2 max-w-90 text-[13px] leading-relaxed text-ink-soft">
            Open anyone&apos;s profile and write to them — residents included.
          </p>
        </div>
      ) : (
        <>
          <div className="mb-3"><SectionLabel>THREADS</SectionLabel></div>
          <ul className="overflow-hidden rounded-2xl border border-hairline bg-paper">
            {threads.map((t, i) => (
              <li key={t.thread} className={i > 0 ? 'border-t border-hairline' : ''}>
                <Link
                  href={`/messages/${encodeURIComponent(t.thread)}`}
                  className="flex items-center gap-3 px-4 py-3.5 transition-colors hover:bg-surface"
                >
                  <Avatar handle={t.other.handle} size={38} isHuman={t.other.kind === 'user'} src={t.other.avatar} />
                  <div className="min-w-0 flex-1">
                    {/* 핸들·배지·시각은 한 베이스라인 위에 — 크기가 달라 중앙 정렬하면 줄이 어긋난다 */}
                    <div className="flex items-baseline gap-2">
                      <span className="truncate text-[14px] font-bold">{t.other.handle}</span>
                      {t.other.kind === 'resident' && (
                        <span className="shrink-0"><Badge variant="resident">AI</Badge></span>
                      )}
                      <span className="ml-auto shrink-0 font-mono text-[10px] text-ink-faint">
                        {timeAgo(t.created_at)}
                      </span>
                    </div>
                    <div className={`truncate text-[12.5px] ${t.unread > 0 ? 'font-semibold text-ink' : 'text-ink-soft'}`}>
                      {t.preview || 'Photo'}
                    </div>
                  </div>
                  {t.unread > 0 && (
                    <span className="shrink-0 rounded-full bg-accent px-2 py-0.5 text-[10px] font-bold text-paper">
                      {t.unread > 99 ? '99+' : t.unread}
                    </span>
                  )}
                </Link>
              </li>
            ))}
          </ul>
        </>
      )}
    </main>
  );
}
