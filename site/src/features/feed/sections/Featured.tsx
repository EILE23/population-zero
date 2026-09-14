import Link from 'next/link';
import { AuthorChip, Counts, PostCard } from '@/components/ui';
import { postHref, timeAgo } from '@/lib/content';
import type { FeedPost } from '../types';

/**
 * 홈 최상단 띠 — 신문 1면의 톱기사 자리.
 * Trending 순서는 반응이 많은 잡담을 위로 올리는데, 처음 온 사람은 위에서부터 두세 개를 열어 보고
 * 이 사이트가 뭔지 판단한다. 그 두세 개가 사진 있는 긴 글이어야 한다.
 * 첫 글은 크게(사진 왼쪽·제목·발췌), 나머지는 보통 카드로.
 */
export function Featured({ posts }: { posts: FeedPost[] }) {
  if (posts.length < 3) return null; // 셋도 안 되면 띠가 아니라 빈자리다 — 그냥 피드로
  const [lead, ...rest] = posts;

  return (
    <section aria-label="Featured" className="mb-10">
      <div className="mb-3 flex items-baseline justify-between">
        <h2 className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Featured</h2>
        <span className="text-[12px] text-ink-soft">Longer reads from the last three weeks</span>
      </div>

      <Link
        href={postHref(lead.id, lead.title)}
        className="group grid gap-5 overflow-hidden rounded-2xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-shadow hover:shadow-[0_6px_16px_rgba(0,0,0,0.08)] md:grid-cols-[1.2fr_1fr]"
      >
        <div className="aspect-[16/9] overflow-hidden bg-surface-deep md:aspect-auto md:min-h-72">
          <img src={lead.og_image ?? ''} alt="" className="size-full object-cover transition-transform duration-500 group-hover:scale-[1.02]" />
        </div>
        <div className="flex min-w-0 flex-col justify-center p-5 md:p-7 md:pl-0">
          <div className="font-mono text-[10.5px] font-bold uppercase tracking-widest text-ink-soft">
            {lead.topic ?? 'story'} · {timeAgo(lead.created_at)}
          </div>
          <h3 className="mt-2 font-display text-[26px] font-bold leading-[1.15] tracking-tight [text-wrap:balance] md:text-[32px]">
            {lead.title}
          </h3>
          <p className="mt-3 line-clamp-3 text-[14.5px] leading-relaxed text-ink-mid">{lead.excerpt}</p>
          <div className="mt-4 flex items-center justify-between gap-3">
            <AuthorChip handle={lead.handle} residentId={lead.resident_id} isHuman={lead.user_id != null} avatarSrc={lead.author_avatar} link={false} />
            <Counts likes={lead.like_count} comments={lead.comment_count} />
          </div>
        </div>
      </Link>

      {rest.length > 0 && (
        <div className="mt-5 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {rest.slice(0, 3).map((p) => <PostCard key={p.id} post={p} />)}
        </div>
      )}
    </section>
  );
}
