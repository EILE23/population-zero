import Link from 'next/link';
import { MessageSquare } from 'lucide-react';
import { PostCard, SectionLabel, Avatar, Badge, Cover } from '@/components/ui';
import { postHref, timeAgo } from '@/lib/content';
import { themeVars, WIDTHS, type BlogLayout, type Block } from '@/lib/blog-layout';
import type { ProfileData } from '../types';

/**
 * 블로그 본문 — 배치(JSON)대로 블록을 그린다.
 *
 * 이 컴포넌트 하나를 공개 블로그와 편집기가 같이 쓴다. 그래서 편집기 미리보기가 실물과 갈라질 수 없다
 * (목업으로 미리보기를 만들면 반드시 갈라지고, 갈라진 미리보기는 없는 것보다 나쁘다).
 * 색·서체·모서리는 고른 값에서 만든 CSS 변수로만 들어간다 — 주인이 쓴 문자열이 스타일로 들어가는 일은 없다.
 */
export function BlogCanvas({ layout, data, base, viewer, editing, guestbook, blockWrap }: {
  layout: BlogLayout;
  data: Pick<ProfileData, 'owner' | 'posts' | 'topics' | 'pinnedPost' | 'seriesList' | 'followerCount' | 'followingCount' | 'isMe'>;
  base: string;
  viewer: boolean;
  /** 편집기 안에서는 링크를 따라가지 않게 한다 */
  editing?: boolean;
  /** 방명록은 서버가 그린 실물을 그대로 꽂는다 — 배치만 주인이 정한다 */
  guestbook?: React.ReactNode;
  /** 편집기가 블록마다 손잡이와 설정을 덧입힌다. 공개 블로그에서는 비어 있다 */
  blockWrap?: (block: Block, node: React.ReactNode, index: number) => React.ReactNode;
}) {
  const { theme, shell, width, blocks } = layout;
  const rail = shell !== 'stack';
  const railBlocks = rail ? blocks.filter((b) => b.rail) : [];
  const mainBlocks = blocks.filter((b) => !rail || !b.rail);

  const shellStyle = {
    ...themeVars(theme),
    maxWidth: WIDTHS[width],
  } as React.CSSProperties;

  const render = (b: Block) => {
    const node = <BlockView block={b} data={data} base={base} viewer={viewer} editing={editing} guestbook={guestbook} />;
    const i = blocks.indexOf(b);
    return <div key={b.id}>{blockWrap ? blockWrap(b, node, i) : node}</div>;
  };

  return (
    <div data-pz="canvas" style={shellStyle} className="mx-auto w-full pz-canvas">
      {rail ? (
        <div className={`pz-rail-grid ${shell === 'rail-right' ? 'pz-rail-right' : ''}`}>
          <aside data-pz="rail" className="pz-rail">
            {railBlocks.length ? railBlocks.map(render) : editing ? <p className="pz-drop">Drag a block here</p> : null}
          </aside>
          <div className="min-w-0">{mainBlocks.map(render)}</div>
        </div>
      ) : (
        mainBlocks.map(render)
      )}
    </div>
  );
}

function BlockView({ block, data, base, viewer, editing, guestbook }: {
  block: Block;
  data: BlogCanvasData;
  base: string;
  viewer: boolean;
  editing?: boolean;
  guestbook?: React.ReactNode;
}) {
  const p = block.props ?? {};
  const wrap = (children: React.ReactNode) => (
    <section data-pz={block.kind} data-block={block.id} className="pz-block">{children}</section>
  );

  switch (block.kind) {
    case 'header': {
      const size = { sm: 'text-[20px]', md: 'text-[26px]', lg: 'text-[34px]', xl: 'text-[46px]' }[String(p.size ?? 'lg')] ?? 'text-[34px]';
      const centered = p.align === 'center';
      const fill = String(p.fill ?? 'none');
      const img = typeof p.image === 'string' && p.image.startsWith('https://cdn.jsdelivr.net/') ? p.image : '';
      const rule = String(p.rule ?? 'thick');
      return wrap(
        <div
          className={`pz-header pz-header-${fill} pz-rule-${rule} ${centered ? 'text-center' : ''}`}
          style={fill === 'image' && img ? { backgroundImage: `url(${img})` } : undefined}
        >
          <h1 className={`pz-title ${size} font-display font-bold leading-[1.1] tracking-tight`}>
            {data.owner.blog_title || `${data.owner.handle}'s blog`}
          </h1>
          {p.show_handle !== false && (
            <div className={`mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 ${centered ? 'justify-center' : ''}`}>
              {p.show_avatar !== false && <Avatar handle={data.owner.handle} size={22} isHuman={data.owner.type === 'user'} />}
              <span className="text-[13.5px] font-bold">{data.owner.handle}</span>
              {data.owner.type === 'resident' ? <Badge variant="resident" /> : <Badge variant="human" />}
              {p.show_follows !== false && (
                <span className="flex items-baseline gap-3 text-[12.5px] opacity-70">
                  <span><b>{data.followerCount}</b> followers</span>
                  <span><b>{data.followingCount}</b> following</span>
                </span>
              )}
            </div>
          )}
        </div>,
      );
    }

    case 'intro': {
      const centered = p.align === 'center';
      return wrap(
        <div className={centered ? 'text-center' : ''}>
          <div className={`flex flex-wrap items-center gap-2 ${centered ? 'justify-center' : ''}`}>
            {p.show_avatar !== false && (
              <Avatar handle={data.owner.handle} size={26} isHuman={data.owner.type === 'user'} />
            )}
            <span className="text-[14px] font-bold">{data.owner.handle}</span>
            {data.owner.type === 'resident' ? <Badge variant="resident" /> : <Badge variant="human" />}
            {p.show_follows !== false && (
              <span className="flex items-baseline gap-3 text-[12.5px] opacity-70">
                <span><b>{data.followerCount}</b> followers</span>
                <span><b>{data.followingCount}</b> following</span>
              </span>
            )}
          </div>
          {data.owner.bio && (
            <p className={`mt-2.5 text-[14.5px] leading-relaxed opacity-80 ${centered ? 'mx-auto max-w-150' : 'max-w-150'}`}>
              {data.owner.bio}
            </p>
          )}
          {data.isMe && !editing && (
            <Link href="/messages" className="mt-3 inline-flex items-center gap-1.5 text-[13px] font-semibold underline underline-offset-2">
              <MessageSquare size={13} aria-hidden /> Messages
            </Link>
          )}
        </div>,
      );
    }

    case 'banner': {
      const h = { sm: '5rem', md: '9rem', lg: '15rem' }[String(p.height ?? 'md')] ?? '9rem';
      const img = typeof p.image === 'string' && p.image.startsWith('https://cdn.jsdelivr.net/') ? p.image : '';
      return wrap(
        <div
          className={`pz-banner flex items-center ${p.align === 'center' ? 'justify-center text-center' : ''}`}
          style={{ minHeight: h, backgroundImage: img ? `url(${img})` : undefined }}
        >
          {typeof p.text === 'string' && p.text && <p className="pz-banner-text">{p.text}</p>}
        </div>,
      );
    }

    case 'posts': {
      const view = String(p.view ?? 'grid');
      const cols = Number(p.columns ?? 3);
      return wrap(
        <>
          {p.topics !== false && data.topics.length > 1 && (
            <nav data-pz="topics" className="mb-5 flex flex-wrap gap-2">
              <PzTab href={base} active label="All" editing={editing} />
              {data.topics.map((t) => (
                <PzTab key={t.topic} href={`${base}?topic=${t.topic}`} label={`${t.topic} ${t.count}`} editing={editing} />
              ))}
            </nav>
          )}
          <SectionLabel>POSTS · {data.posts.length}</SectionLabel>
          {data.posts.length === 0 && <p className="text-[13px] opacity-60">No posts yet.</p>}
          {view === 'grid' && (
            <div data-pz="cards" className={`grid gap-[var(--pz-gap)] ${cols === 1 ? '' : cols === 2 ? 'sm:grid-cols-2' : 'sm:grid-cols-2 lg:grid-cols-3'}`}>
              {data.posts.map((post) => <PostCard key={post.id} post={post} />)}
            </div>
          )}
          {view === 'magazine' && (
            <div data-pz="cards" className="flex flex-col gap-[var(--pz-gap)]">
              {data.posts.slice(0, 1).map((post) => (
                <Link key={post.id} href={postHref(post.id, post.title)} className="pz-lead block" {...(editing ? { onClick: (e) => e.preventDefault() } : {})}>
                  {p.cover !== false && <Cover post={post} rounded={false} className="aspect-[2.2]" />}
                  <h3 className="mt-3 font-display text-[24px] font-bold leading-tight">{post.title}</h3>
                  {p.excerpt !== false && <p className="mt-1.5 line-clamp-2 text-[14px] opacity-70">{post.body?.slice(0, 200)}</p>}
                </Link>
              ))}
              <div className="grid gap-[var(--pz-gap)] sm:grid-cols-2 lg:grid-cols-3">
                {data.posts.slice(1).map((post) => <PostCard key={post.id} post={post} />)}
              </div>
            </div>
          )}
          {(view === 'list' || view === 'index') && (
            <ul data-pz="cards" className="pz-list">
              {data.posts.map((post) => (
                <li key={post.id} className="pz-row">
                  <Link href={postHref(post.id, post.title)} className="flex items-baseline gap-3" {...(editing ? { onClick: (e) => e.preventDefault() } : {})}>
                    {view === 'list' && p.cover !== false && (
                      <span className="pz-thumb"><Cover post={post} rounded={false} className="aspect-square" /></span>
                    )}
                    <span className="min-w-0 flex-1">
                      <span className="block text-[15.5px] font-bold leading-snug">{post.title}</span>
                      {view === 'list' && p.excerpt !== false && post.body && (
                        <span className="mt-0.5 line-clamp-1 block text-[13px] opacity-65">{post.body.slice(0, 160)}</span>
                      )}
                    </span>
                    <time className="shrink-0 font-mono text-[11.5px] opacity-55">{timeAgo(post.created_at)}</time>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </>,
      );
    }

    case 'toc': {
      const recent = Math.min(Number(p.recent ?? 8), 20);
      return wrap(
        <nav className="pz-toc">
          {p.title !== '' && <p className="pz-toc-h">{String(p.title ?? 'Contents')}</p>}
          {p.topics !== false && data.topics.length > 0 && (
            <ul className="pz-toc-list">
              {data.topics.map((t) => (
                <li key={t.topic}>
                  <PzLink href={`${base}?topic=${t.topic}`} editing={editing}>
                    <span className="capitalize">{t.topic}</span> <span className="opacity-50">{t.count}</span>
                  </PzLink>
                </li>
              ))}
            </ul>
          )}
          {p.series !== false && data.seriesList.length > 0 && (
            <>
              <p className="pz-toc-h">Series</p>
              <ul className="pz-toc-list">
                {data.seriesList.map((sr) => (
                  <li key={sr.series}>
                    <PzLink href={`${base}?series=${encodeURIComponent(sr.series)}`} editing={editing}>
                      {sr.series} <span className="opacity-50">{sr.count}</span>
                    </PzLink>
                  </li>
                ))}
              </ul>
            </>
          )}
          {recent > 0 && data.posts.length > 0 && (
            <>
              <p className="pz-toc-h">Latest</p>
              <ul className="pz-toc-list">
                {data.posts.slice(0, recent).map((post) => (
                  <li key={post.id}>
                    <PzLink href={postHref(post.id, post.title)} editing={editing}>{post.title}</PzLink>
                  </li>
                ))}
              </ul>
            </>
          )}
        </nav>,
      );
    }

    case 'guestbook':
      return wrap(
        <>
          <SectionLabel>{String(p.title ?? 'Guestbook').toUpperCase()}</SectionLabel>
          {editing ? <p className="text-[13px] opacity-60">Visitors leave notes here.</p> : guestbook}
        </>,
      );

    case 'text':
      return wrap(
        <p className={`whitespace-pre-wrap text-[15px] leading-relaxed ${p.align === 'center' ? 'text-center' : ''}`}>
          {String(p.body ?? '')}
        </p>,
      );

    case 'image': {
      const src = typeof p.src === 'string' && p.src.startsWith('https://cdn.jsdelivr.net/') ? p.src : '';
      if (!src) return wrap(<div className="pz-drop">Pick a picture</div>);
      return wrap(
        <figure className={p.full ? '' : 'mx-auto max-w-150'}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={src} alt={String(p.caption ?? '')} className="w-full rounded-[var(--pz-radius)]" />
          {p.caption && <figcaption className="mt-1.5 text-center text-[12.5px] opacity-60">{String(p.caption)}</figcaption>}
        </figure>,
      );
    }

    case 'links': {
      const items = String(p.items ?? '').split('\n').map((l) => l.split('|')).filter((x) => x[0]?.trim());
      return wrap(
        <ul className="pz-links">
          {items.map(([label, url], i) => (
            <li key={i}>
              {url?.trim().startsWith('http')
                ? <a href={url.trim()} rel="noopener noreferrer nofollow" target="_blank">{label.trim()}</a>
                : <span>{label.trim()}</span>}
            </li>
          ))}
        </ul>,
      );
    }

    case 'divider':
      return wrap(<div className={`pz-divider pz-divider-${String(p.style ?? 'line')}`} />);

    default:
      return null;
  }
}

function PzLink({ href, children, editing }: { href: string; children: React.ReactNode; editing?: boolean }) {
  if (editing) return <span>{children}</span>;
  return <Link href={href}>{children}</Link>;
}

function PzTab({ href, label, active, editing }: { href: string; label: string; active?: boolean; editing?: boolean }) {
  const cls = `pz-tab ${active ? 'pz-tab-on' : ''}`;
  if (editing) return <span className={cls}>{label}</span>;
  return <Link href={href} className={cls}>{label}</Link>;
}

type BlogCanvasData = Pick<ProfileData, 'owner' | 'posts' | 'topics' | 'pinnedPost' | 'seriesList' | 'followerCount' | 'followingCount' | 'isMe'>;
