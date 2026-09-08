import Link from 'next/link';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { Avatar, Badge } from '@/components/ui';
import { NavActions } from '@/features/layout/NavActions';
import { Footer } from '@/features/layout/Footer';
import { HandlePickerModal } from '@/features/auth/HandlePickerModal';
import { EditableBlogTitle } from '@/features/blog/components/EditableBlogTitle';
import { handleSlug } from '@/lib/content';

// 블로그 크롬 — 헤더 좌측 상단이 사이트 로고 대신 "이 블로그"가 된다 (진짜 내 블로그처럼)
export default async function BlogLayout({ children, params }: { children: React.ReactNode; params: Promise<{ profile: string }> }) {
  const { profile } = await params;
  const decoded = decodeURIComponent(profile);
  const slug = decoded.startsWith('@') ? decoded.slice(1) : null;

  let owner: { type: 'user' | 'resident'; id: number; handle: string; blog_title: string | null; tier?: string; avatar_url?: string | null } | null = null;
  let counts = { followers: 0, following: 0 };
  let viewer = null;
  if (slug) {
    try {
      const db = await getDb();
      viewer = await getSessionUser();
      owner =
        await db.prepare(`SELECT id, handle, blog_title, avatar_url, 'user' AS type FROM users WHERE handle = ? COLLATE NOCASE`).bind(slug)
          .first<{ id: number; handle: string; blog_title: string | null; avatar_url: string | null; type: 'user' }>()
        ?? await db.prepare(`SELECT id, handle, blog_title, tier, 'resident' AS type FROM residents WHERE lower(replace(handle,' ','-')) = ?`).bind(slug.toLowerCase())
          .first<{ id: number; handle: string; blog_title: string | null; tier: string; type: 'resident' }>();
      if (owner) {
        const row = await db.prepare(`SELECT
            (SELECT COUNT(*) FROM follows WHERE target_type = ?1 AND target_id = ?2) AS followers,
            (SELECT COUNT(*) FROM follows WHERE follower_type = ?1 AND follower_id = ?2) AS following`)
          .bind(owner.type, owner.id).first<{ followers: number; following: number }>();
        if (row) counts = row;
      }
    } catch { /* 셸은 항상 렌더 */ }
  }

  const isMe = viewer != null && owner?.type === 'user' && viewer.id === owner.id;
  const base = owner ? `/@${handleSlug(owner.handle)}` : '/';
  const isResident = owner?.type === 'resident';

  return (
    <div className="mx-auto flex min-h-svh max-w-7xl flex-col px-5 md:px-8">
      <header className="border-b-2 border-ink py-5">
        <div className="mb-3 font-mono text-[10.5px] font-bold uppercase tracking-[0.16em] text-ink-soft">
          <Link href="/" className="hover:text-ink">← Population: Zero</Link>
        </div>
        <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
          <div className="min-w-0">
            {owner && (
              <>
                {isMe
                  ? <EditableBlogTitle initialTitle={owner.blog_title} fallback={`${owner.handle}'s blog`} />
                  : (
                    <Link href={base} className="block font-display text-[30px] font-bold leading-tight tracking-tight hover:opacity-80 md:text-[38px]">
                      {owner.blog_title || `${owner.handle}'s blog`}
                    </Link>
                  )}
                <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1">
                  <span className="flex items-center gap-2">
                    <Avatar handle={owner.handle} size={24} isHuman={!isResident} src={owner.avatar_url ?? null} />
                    <span className="text-[13.5px] font-bold">{owner.handle}</span>
                    {isResident
                      ? <Badge variant={owner.tier === 'admin' ? 'admin' : 'resident'}>{owner.tier === 'admin' ? 'ADMIN' : 'AI'}</Badge>
                      : <Badge variant="human">HUMAN</Badge>}
                  </span>
                  <span className="flex gap-3 text-[12.5px] text-ink-soft">
                    <Link className="hover:underline" href={`${base}/follows`}><b className="text-ink">{counts.followers}</b> followers</Link>
                    <Link className="hover:underline" href={`${base}/follows?tab=following`}><b className="text-ink">{counts.following}</b> following</Link>
                  </span>
                </div>
              </>
            )}
          </div>
          <NavActions />
        </div>
      </header>
      <div className="flex-1 pb-16">{children}</div>
      <Footer />
      {viewer && !viewer.handle_picked && viewer.google_sub && <HandlePickerModal currentHandle={viewer.handle} />}
    </div>
  );
}
