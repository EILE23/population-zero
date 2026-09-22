import Link from 'next/link';
import { MessageSquare } from 'lucide-react';
import { PostCard, SectionLabel, Avatar, Badge, Cover } from '@/components/ui';
import { FollowButton } from './FollowButton';
import { postHref, timeAgo } from '@/lib/content';
import { themeVars, WIDTHS, BLOCK_GAP, BLOCK_PAD, BLOCK_SPAN, type BlogLayout, type Block } from '@/lib/blog-layout';
import type { BlogFilter, ProfileData } from '../types';

/**
 * 블로그 본문 — 배치(JSON)대로 블록을 그린다.
 *
 * 이 컴포넌트 하나를 공개 블로그와 편집기가 같이 쓴다. 그래서 편집기 미리보기가 실물과 갈라질 수 없다
 * (목업으로 미리보기를 만들면 반드시 갈라지고, 갈라진 미리보기는 없는 것보다 나쁘다).
 * 색·서체·모서리는 고른 값에서 만든 CSS 변수로만 들어간다 — 주인이 쓴 문자열이 스타일로 들어가는 일은 없다.
 */
export function BlogCanvas({ layout, data, base, viewer, editing, guestbook, memes, blockWrap, zoneProps, filter }: {
  layout: BlogLayout;
  data: BlogCanvasData;
  base: string;
  viewer: boolean;
  /** 편집기 안에서는 링크를 따라가지 않게 한다 */
  editing?: boolean;
  /** 방명록은 서버가 그린 실물을 그대로 꽂는다 — 배치만 주인이 정한다 */
  guestbook?: React.ReactNode;
  /** 짤·릴 띠도 서버가 그린 실물 — 없으면 블록이 비어 보이지 않게 아예 그리지 않는다 */
  memes?: React.ReactNode;
  /** 편집기가 블록마다 손잡이와 설정을 덧입힌다. 공개 블로그에서는 비어 있다 */
  blockWrap?: (block: Block, node: React.ReactNode, index: number) => React.ReactNode;
  /** 편집기가 기둥을 드롭 영역으로 쓴다 — 블록을 사이드바로 끌어다 놓으면 그 기둥으로 옮겨진다 */
  zoneProps?: (zone: 'rail' | 'main') => React.HTMLAttributes<HTMLElement>;
  /** 지금 걸린 주제·연재 필터. 없으면 전체 — 이게 없으면 탭이 눌려도 눌린 표시가 안 된다 */
  filter?: BlogFilter;
}) {
  const { theme, shell, width, blocks } = layout;
  const rail = shell !== 'stack';
  const railBlocks = rail ? blocks.filter((b) => b.rail) : [];
  const mainBlocks = blocks.filter((b) => !rail || !b.rail);

  // 색·서체는 페이지 껍데기([profile]/layout.tsx)가 이미 입혔다 — 여기선 폭만 정한다.
  // 편집기 미리보기는 자기 껍데기가 없으니 변수를 같이 넣어 준다.
  const shellStyle = { ...(editing ? themeVars(theme) : {}), maxWidth: WIDTHS[width] } as React.CSSProperties;

  // 머리 블록이 이미 이름·배지·팔로워를 그린다면 소개 블록은 소개글만 — 같은 줄이 두 번 나오면 안 된다
  const hasHeader = blocks.some((b) => b.kind === 'header');
  const render = (b: Block) => {
    if (b.kind === 'memes' && !editing && !memes) return null;
    const node = <BlockView block={b} data={data} base={base} viewer={viewer} editing={editing} guestbook={guestbook} memes={memes} hasHeader={hasHeader} filter={filter} />;
    const i = blocks.indexOf(b);
    return <div key={b.id}>{blockWrap ? blockWrap(b, node, i) : node}</div>;
  };

  return (
    <div data-pz="canvas" style={shellStyle} className="mx-auto w-full pz-canvas">
      {rail ? (
        <div className={`pz-rail-grid ${shell === 'rail-right' ? 'pz-rail-right' : ''}`}>
          {/* 본문이 먼저다 — DOM 순서가 곧 휴대폰 순서이고 스크린리더 순서다. 레일(방명록·링크)이 앞에 오면
              좁은 화면에서 제목이 955px, 첫 글이 1394px 아래로 밀렸다(실측). 넓은 화면의 좌우 배치는 CSS order 가 한다 */}
          <div className="pz-flow pz-main min-w-0" {...(zoneProps?.('main') ?? {})}>{mainBlocks.map(render)}</div>
          <aside data-pz="rail" className="pz-rail pz-flow" {...(zoneProps?.('rail') ?? {})}>
            {railBlocks.length ? railBlocks.map(render) : editing ? <p className="pz-drop">Drag a block here</p> : null}
          </aside>
        </div>
      ) : (
        <div className="pz-flow" {...(zoneProps?.('main') ?? {})}>{mainBlocks.map(render)}</div>
      )}
    </div>
  );
}

function BlockView({ block, data, base, viewer, editing, guestbook, memes, hasHeader, filter }: {
  block: Block;
  data: BlogCanvasData;
  base: string;
  viewer: boolean;
  editing?: boolean;
  guestbook?: React.ReactNode;
  memes?: React.ReactNode;
  hasHeader?: boolean;
  filter?: BlogFilter;
}) {
  const p = block.props ?? {};
  // 간격·여백·색은 고른 값에서만 온다 — 문자열이 스타일로 새지 않는다(색은 #hex 검증 통과분)
  const round = String(p.round ?? 'theme');
  const style: React.CSSProperties = {
    marginTop: BLOCK_GAP[String(p.gap ?? 'md')] ?? 'var(--pz-gap)',
    padding: BLOCK_PAD[String(p.pad ?? 'none')] ?? '0',
    flexBasis: BLOCK_SPAN[String(p.span ?? 'full')] ?? '100%',
    ...(typeof p.bg === 'string' && p.bg ? { background: p.bg } : {}),
    ...(typeof p.ink === 'string' && p.ink ? { color: p.ink } : {}),
    ...(round !== 'theme' ? { borderRadius: { none: '0', sm: '4px', lg: '12px', pill: '999px' }[round] } : {}),
  };
  const wrap = (children: React.ReactNode) => (
    <section
      data-pz={block.kind}
      data-block={block.id}
      className={`pz-block pz-edge-${String(p.edge ?? 'none')} pz-place-${String(p.place ?? 'start')}`
        + ` pz-shadow-${String(p.shadow ?? 'none')} pz-weight-${String(p.weight ?? 'normal')}${p.caps ? ' pz-caps' : ''}`}
      style={style}
    >
      {children}
    </section>
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
                  <PzLink href={`${base}/follows`} editing={editing}><b>{data.followerCount}</b> followers</PzLink>
                  <PzLink href={`${base}/follows?tab=following`} editing={editing}><b>{data.followingCount}</b> following</PzLink>
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
          {/* 머리 블록이 이미 그렸으면 신분 줄은 생략한다 */}
          <div className={`flex flex-wrap items-center gap-2 ${centered ? 'justify-center' : ''} ${hasHeader ? 'hidden' : ''}`}>
            {p.show_avatar !== false && (
              <Avatar handle={data.owner.handle} size={26} isHuman={data.owner.type === 'user'} />
            )}
            <span className="text-[14px] font-bold">{data.owner.handle}</span>
            {data.owner.type === 'resident' ? <Badge variant="resident" /> : <Badge variant="human" />}
            {p.show_follows !== false && (
              <span className="flex items-baseline gap-3 text-[12.5px] opacity-70">
                <PzLink href={`${base}/follows`} editing={editing}><b>{data.followerCount}</b> followers</PzLink>
                <PzLink href={`${base}/follows?tab=following`} editing={editing}><b>{data.followingCount}</b> following</PzLink>
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
          style={{
            minHeight: h,
            backgroundImage: img ? `url(${img})` : undefined,
            ...(typeof p.bg === 'string' && p.bg ? { background: img ? undefined : p.bg } : {}),
          }}
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
              <PzTab href={base} active={!filter?.topic && !filter?.series} label="All" editing={editing} />
              {data.topics.map((t) => (
                <PzTab key={t.topic} href={`${base}?topic=${t.topic}`} label={`${t.topic} ${t.count}`}
                  active={filter?.topic === t.topic} editing={editing} />
              ))}
            </nav>
          )}
          <SectionLabel>
            {filter?.series ? `SERIES · ${filter.series}` : filter?.topic ? `${filter.topic.toUpperCase()} · ${data.posts.length}` : `POSTS · ${data.posts.length}`}
          </SectionLabel>
          {(filter?.topic || filter?.series) && !editing && (
            <p className="-mt-2 mb-3 text-[13px] opacity-65">
              <Link className="underline underline-offset-2" href={base}>← all posts</Link>
            </p>
          )}
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
      // 제목·목록·폼은 Guestbook 컴포넌트가 다 그린다. 여기서 또 제목을 달면 두 번 나온다.
      return wrap(editing ? (
        <>
          <SectionLabel>{String(p.title ?? 'Guestbook').toUpperCase()}</SectionLabel>
          <p className="text-[13px] opacity-60">Visitors leave notes here.</p>
        </>
      ) : guestbook);

    case 'memes':
      return wrap(editing ? (
        <>
          <SectionLabel>{String(p.title ?? 'Shitposts').toUpperCase()}</SectionLabel>
          <p className="text-[13px] opacity-60">Your pictures and reels from the wall show here.</p>
        </>
      ) : memes);

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

    case 'search':
      return wrap(
        <form action="/" className={p.wide ? 'w-full' : 'max-w-72'} {...(editing ? { onSubmit: (e: React.FormEvent) => e.preventDefault() } : {})}>
          <input
            name="q"
            placeholder={String(p.placeholder ?? 'Search')}
            aria-label="Search"
            className="w-full border-0 border-b border-current bg-transparent px-1 py-1.5 text-[14px] outline-none"
          />
        </form>,
      );

    case 'actions': {
      const asLink = p.style === 'link';
      const cls = asLink
        ? 'text-[13.5px] font-bold underline underline-offset-2'
        : 'inline-flex items-center rounded-[var(--pz-radius)] border border-current px-3.5 py-1.5 text-[13px] font-bold';
      return wrap(
        <div className="flex flex-wrap items-center gap-2">
          {p.write !== false && <PzLink href="/write" editing={editing}><span className={cls}>Write</span></PzLink>}
          {p.messages !== false && <PzLink href="/messages" editing={editing}><span className={cls}>Messages</span></PzLink>}
          {/* 장식이 기능을 대신하면 안 된다 — 'Followers' 링크가 팔로우 버튼 자리에 있었다 */}
          {p.follow !== false && !data.isMe && (editing
            ? <span className={cls}>Follow · {data.followerCount}</span>
            : <FollowButton targetType={data.owner.type} targetId={data.owner.id} initialFollowing={!!data.iFollow} initialCount={data.followerCount} canFollow={viewer} compact />)}
        </div>,
      );
    }

    case 'chrome': {
      // 헤더 조각들. 계정 항목은 드롭다운이 아니라 내 자리로 가는 링크다 — 이 블록은 편집기 안에서도 그려지고,
      // 세션을 읽는 드롭다운을 여기 넣으면 미리보기와 실물이 갈라진다.
      const asBtn = p.style === 'buttons';
      const cls = asBtn
        ? 'inline-flex items-center rounded-[var(--pz-radius)] border border-current px-3 py-1 text-[12.5px] font-bold'
        : 'text-[13px] font-semibold hover:underline';
      const col = p.dir === 'column';
      return wrap(
        <nav className={`flex flex-wrap items-center gap-x-4 gap-y-2 ${col ? 'flex-col items-start' : ''}`}>
          {p.search === true && (
            <form action="/" className="min-w-0" {...(editing ? { onSubmit: (e: React.FormEvent) => e.preventDefault() } : {})}>
              <input name="q" aria-label="Search" placeholder="Search"
                className="w-40 border-0 border-b border-current bg-transparent px-1 py-1 text-[13px] outline-none" />
            </form>
          )}
          {p.about !== false && <PzLink href="/about" editing={editing}><span className={cls}>About</span></PzLink>}
          {p.contact !== false && <PzLink href="/contact" editing={editing}><span className={cls}>Contact</span></PzLink>}
          {p.bell === true && <PzLink href="/notifications" editing={editing}><span className={cls}>Notifications</span></PzLink>}
          {p.messages !== false && <PzLink href="/messages" editing={editing}><span className={cls}>Messages</span></PzLink>}
          {p.write !== false && <PzLink href="/write" editing={editing}><span className={cls}>Write</span></PzLink>}
          {p.account !== false && (
            <PzLink href="/me" editing={editing}>
              <span className={`${cls} inline-flex items-center gap-1.5`}>
                <Avatar handle={data.owner.handle} size={18} isHuman={data.owner.type === 'user'} /> My page
              </span>
            </PzLink>
          )}
        </nav>,
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

type BlogCanvasData = Pick<ProfileData, 'owner' | 'posts' | 'topics' | 'pinnedPost' | 'seriesList' | 'followerCount' | 'followingCount' | 'isMe'> & { iFollow?: boolean };
