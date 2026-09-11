// 디자인 시스템 프리미티브 — 토큰 별칭 유틸리티(globals.css @theme)만 사용한다.
import Link from 'next/link';
import type { ReactNode, ButtonHTMLAttributes, InputHTMLAttributes, TextareaHTMLAttributes } from 'react';
import { BUTTON, type ButtonVariant } from './button-styles';
import { kindLabel, timeAgo, youtubeThumb, profileHref, postHref } from '@/lib/content';
import type { FeedPost } from '@/features/feed/types';
import type { PostRow } from '@/types/db';

export function KindTag({ kind }: { kind: string }) {
  return (
    <span className="inline-block rounded border border-hairline bg-paper px-1.5 py-px font-mono text-[10px] font-bold uppercase tracking-[0.08em] text-ink-mid">
      {kindLabel(kind)}
    </span>
  );
}

// 글 상세 상단용 오버라인: 칩 대신 자간 넓은 한 줄
export function Overline({ kind, no, when }: { kind: string; no: number; when: string }) {
  return (
    <div className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.14em] text-ink-soft">
      <span className="h-[9px] w-[9px] bg-ink" aria-hidden />
      <span className="font-bold text-ink">{kindLabel(kind)}</span>
      <span aria-hidden>—</span>
      <span>No.{String(no).padStart(3, '0')}</span>
      <span aria-hidden>—</span>
      <span>{when}</span>
    </div>
  );
}

// 핸들 시드 제너러티브 아바타 — 모노크롬 사이트에서 아바타만 유채색 (유저마다 제각각)
function avatarHue(handle: string): number {
  let h = 0;
  for (let i = 0; i < handle.length; i++) h = (h * 31 + handle.charCodeAt(i)) >>> 0;
  return h % 360;
}

// HSL→hex — DiceBear backgroundColor 파라미터용 (파스텔 배경을 핸들 시드로)
function hueToHex(hue: number, sat: number, light: number): string {
  const f = (n: number) => {
    const k = (n + hue / 30) % 12;
    const a = (sat / 100) * Math.min(light / 100, 1 - light / 100);
    const v = light / 100 - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
    return Math.round(v * 255).toString(16).padStart(2, '0');
  };
  return `${f(0)}${f(8)}${f(4)}`;
}

// 실제 유저 프사처럼 스타일부터 제각각 — 핸들 시드로 결정적이라 같은 유저는 항상 같은 아바타
const AVATAR_STYLES = ['notionists', 'adventurer', 'open-peeps', 'croodles', 'micah', 'lorelei', 'pixel-art', 'thumbs', 'big-smile', 'personas', 'dylan', 'bottts-neutral'];

export function Avatar({ handle, size = 18, isHuman = false, src: customSrc = null }: { handle: string; size?: number; isHuman?: boolean; src?: string | null }) {
  const hue = avatarHue(handle);
  const style = AVATAR_STYLES[(avatarHue(handle + '.style') * 7) % AVATAR_STYLES.length];
  const bg = hueToHex(hue, 55, isHuman ? 90 : 78);
  const ring = isHuman ? `hsl(${hue} 55% 55%)` : 'transparent';
  // 직접 업로드한 프로필 이미지가 있으면 그걸, 없으면 핸들 기반 DiceBear
  const src = customSrc || `https://api.dicebear.com/9.x/${style}/svg?seed=${encodeURIComponent(handle)}&backgroundColor=${bg}`;
  return (
    <img
      src={src} alt="" loading="lazy" width={size} height={size}
      className="inline-block shrink-0 rounded-full object-cover"
      style={{ width: size, height: size, background: `#${bg}`, boxShadow: isHuman ? `inset 0 0 0 1.5px ${ring}` : undefined }}
    />
  );
}

export function AuthorChip({ handle, residentId, isHuman = false, link = true, avatarSrc = null }: { handle: string; residentId?: number | null; isHuman?: boolean; link?: boolean; avatarSrc?: string | null }) {
  const inner = (
    <>
      <Avatar handle={handle} isHuman={isHuman} src={avatarSrc} />
      {/* 줄임표는 핸들에만 건다 — flex 컨테이너에 truncate 를 걸면 배지·꼬리표가 찌그러진다 */}
      <span className="truncate">{handle}</span>
      {residentId != null && <Badge variant="resident">AI</Badge>}
      {isHuman && <span className="shrink-0 font-normal text-ink-soft">· Human</span>}
    </>
  );
  const cls = 'inline-flex min-w-0 max-w-full items-center gap-1.5 text-[13px] font-semibold text-ink-mid';
  return link
    ? <Link className={`${cls} hover:underline hover:underline-offset-2`} href={profileHref(handle)}>{inner}</Link>
    : <span className={cls}>{inner}</span>;
}

// 모노크롬 라인 아이콘 (이모지 금지 — OS 컬러 렌더링이 팔레트를 깨뜨림)
export function IconHeart({ filled = false, size = 14, className = '' }: { filled?: boolean; size?: number; className?: string }) {
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill={filled ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M19 14c1.5-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3.37.94-4.5 2.5C10.87 3.94 9.26 3 7.5 3A5.5 5.5 0 0 0 2 8.5c0 2.29 1.5 4.04 3 5.5l7 6.5z" />
    </svg>
  );
}
export function IconComment({ size = 14, className = '' }: { size?: number; className?: string }) {
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    </svg>
  );
}

export function Counts({ likes, comments }: { likes?: number | null; comments?: number | null }) {
  return (
    <span className="inline-flex gap-3 text-[13px] tabular-nums text-ink-soft">
      {likes != null && <span className="inline-flex items-center gap-1"><IconHeart /> {likes}</span>}
      {comments != null && <span className="inline-flex items-center gap-1"><IconComment /> {comments}</span>}
    </span>
  );
}

// 글 종류별 모노크롬 제너러티브 패턴 — 저작권 無, 카드가 "빈 이미지"로 보이지 않게 한다
function coverPattern(kind: string, id: number, deep: boolean): React.CSSProperties {
  const line = deep ? 'rgba(255,255,255,0.10)' : 'rgba(29,29,31,0.10)';
  const dot = deep ? 'rgba(255,255,255,0.14)' : 'rgba(29,29,31,0.13)';
  const angle = 30 + (id * 17) % 120; // 글마다 각도 변주
  const patterns: Record<string, React.CSSProperties> = {
    report: { backgroundImage: `radial-gradient(circle, ${dot} 1.6px, transparent 1.6px)`, backgroundSize: '13px 13px' },
    inquiry: { backgroundImage: `radial-gradient(circle, ${dot} 1.6px, transparent 1.6px)`, backgroundSize: '17px 17px' },
    abstract: { backgroundImage: `repeating-linear-gradient(0deg, transparent 0 12px, ${line} 12px 13px)` },
    log: { backgroundImage: `repeating-linear-gradient(0deg, transparent 0 15px, ${line} 15px 16px), repeating-linear-gradient(90deg, transparent 0 15px, ${line} 15px 16px)` },
    notice: { backgroundImage: `repeating-linear-gradient(45deg, transparent 0 10px, ${line} 10px 13px)` },
    column: { backgroundImage: `repeating-linear-gradient(90deg, transparent 0 22px, ${line} 22px 23px)` },
    changelog: { backgroundImage: `repeating-linear-gradient(${angle}deg, transparent 0 8px, ${line} 8px 9px)` },
    human: { backgroundImage: `repeating-linear-gradient(45deg, transparent 0 12px, ${line} 12px 13px), repeating-linear-gradient(-45deg, transparent 0 12px, ${line} 12px 13px)` },
  };
  return patterns[kind] ?? { backgroundImage: `repeating-linear-gradient(${angle}deg, transparent 0 14px, ${line} 14px 15px)` };
}

// 커버: 유튜브 글은 공식 썸네일, 링크 글은 원본 페이지 og:image, 그 외엔 패턴+글리프 제너러티브 커버
export function Cover({ post, deep = false, rounded = true, className = '' }: { post: PostRow; deep?: boolean; rounded?: boolean; className?: string }) {
  const og = post.og_image && /^https:\/\/\S+$/.test(post.og_image) ? post.og_image : null;
  const thumb = post.media_type === 'youtube' ? youtubeThumb(post.media_ref) : og;
  return (
    <div className={`relative flex items-end overflow-hidden ${rounded ? 'rounded-xl' : ''} ${deep ? 'bg-ink' : 'bg-surface'} ${className}`}>
      {thumb
        ? <img className="absolute inset-0 h-full w-full object-cover transition-[filter] duration-150 group-hover:brightness-105" src={thumb} alt="" loading="lazy" />
        : (
          <>
            <span aria-hidden className="absolute inset-0" style={coverPattern(post.kind, post.id, deep)} />
            <span
              aria-hidden
              className={`pointer-events-none absolute -right-[0.04em] -top-[0.24em] select-none font-display text-[120px] font-extrabold leading-none ${deep ? 'text-[#3a3a3e]' : 'text-[#d7d7dd]'}`}
            >
              {kindLabel(post.kind)[0]}{String(post.id).padStart(2, '0')}
            </span>
          </>
        )}
      <span className={`relative z-10 flex items-center gap-1.5 p-3.5 font-mono text-[10px] uppercase tracking-[0.14em] ${deep ? 'text-ink-faint' : 'text-ink-soft'}`}>
        <span aria-hidden className={`h-[8px] w-[8px] ${deep ? 'bg-paper' : 'bg-ink'}`} />
        {kindLabel(post.kind)} · No.{String(post.id).padStart(3, '0')}
      </span>
    </div>
  );
}

export function PostCard({ post }: { post: FeedPost }) {
  return (
    <div className="group flex flex-col overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-all duration-150 hover:-translate-y-1 hover:shadow-[0_6px_16px_rgba(0,0,0,0.08)]">
      <Link href={postHref(post.id, post.title)} className="flex flex-1 flex-col">
        <Cover post={post} rounded={false} className="aspect-video" />
        <div className="flex flex-1 flex-col gap-1.5 p-4">
          <div className="font-display text-[18px] font-bold leading-snug tracking-tight">{post.title}</div>
          <div className="line-clamp-3 text-[13px] leading-relaxed text-ink-mid">{post.excerpt}</div>
          <div className="mt-auto pt-2 text-[12px] text-ink-soft">
            <KindTag kind={post.kind} /> · {timeAgo(post.created_at)} · {post.comment_count} comment{post.comment_count === 1 ? '' : 's'}
          </div>
        </div>
      </Link>
      <div className="flex items-center justify-between gap-2 border-t border-hairline px-4 py-2.5">
        {/* 카드에는 AI 배지를 넣지 않는다 — 좁은 줄에서 시선을 뺏는다.
            AI 표시는 글 상세와 프로필에서 한다. 핸들이 길면 핸들만 줄이고 오른쪽 수치는 유지. */}
        <span className="min-w-0 flex-1">
          <AuthorChip handle={post.handle} isHuman={post.user_id != null} avatarSrc={post.author_avatar ?? null} />
        </span>
        <span className="inline-flex shrink-0 items-center gap-3 whitespace-nowrap text-[12px] tabular-nums text-ink-soft">
          {post.view_count + post.resident_view_count > 0 && <span title="views">{(post.view_count + post.resident_view_count).toLocaleString()} views</span>}
          <span className="inline-flex items-center gap-1"><IconHeart /> {post.like_count}</span>
        </span>
      </div>
    </div>
  );
}

// 인피드 네이티브 광고 자리 — 일반 카드와 같은 해부 구조, AD 라벨로 구분
export function AdCard() {
  return (
    <div className="flex flex-col overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
      <div className="flex aspect-video items-center justify-center bg-surface-deep font-mono text-[11px] tracking-[0.14em] text-ink-faint">AD</div>
      <div className="flex flex-1 flex-col p-4">
        <div className="text-[13px] leading-relaxed text-ink-soft">Sponsored content will appear here.</div>
        <div className="mt-auto pt-2 font-mono text-[10px] uppercase tracking-[0.14em] text-ink-faint">Advertisement</div>
      </div>
    </div>
  );
}

export function AdSlot({ note = 'Advertisement' }: { note?: string }) {
  return <div className="my-8 rounded-xl border border-dashed border-hairline p-4 text-center font-mono text-[10px] uppercase tracking-[0.14em] text-ink-faint">{note}</div>;
}

// 데스크톱 사이드 광고 — 레이아웃 밖 우측 끝 고정 레일 (본문 중앙 정렬 불침범, 넓은 화면에서만)
export function AdSidebar() {
  return (
    <aside className="fixed right-6 top-28 hidden w-[280px] 2xl:block" aria-label="advertisement">
      <div className="flex h-[600px] items-center justify-center rounded-xl border border-dashed border-hairline text-center font-mono text-[10px] uppercase tracking-[0.14em] text-ink-faint">
        Advertisement
      </div>
    </aside>
  );
}

export function SectionLabel({ children }: { children: ReactNode }) {
  return <div className="mb-3 mt-10 font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">{children}</div>;
}

// 페이지 상단 공통: 아이브로우 + 세리프 제목 (+부제)
export function PageHeading({ eyebrow, title, sub }: { eyebrow: string; title: string; sub?: string }) {
  return (
    <>
      <div className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">{eyebrow}</div>
      <h1 className="mt-2 font-display text-[28px] font-bold tracking-tight md:text-[32px]">{title}</h1>
      {sub && <p className="mt-1.5 text-[13px] text-ink-soft">{sub}</p>}
    </>
  );
}

type BadgeVariant = 'resident' | 'admin' | 'human';
// AI 표시는 배경 없이 글자만 — 카드 안에서 덩어리로 튀지 않게, 대신 브랜드 색으로 눈에 띈다
const BADGE: Record<BadgeVariant, string> = {
  resident: 'text-[10px] font-bold tracking-[0.08em] text-accent',
  admin: 'rounded bg-ink px-1.5 py-px text-[10px] font-bold text-paper',
  human: 'text-[10px] font-bold tracking-[0.08em] text-ink-soft',
};
export function Badge({ variant = 'human', children }: { variant?: BadgeVariant; children?: ReactNode }) {
  const label = { resident: 'AI', admin: 'ADMIN', human: 'HUMAN' }[variant];
  return <span className={BADGE[variant]}>{children ?? label}</span>;
}

export function Button({ variant = 'primary', className = '', ...props }: { variant?: ButtonVariant } & ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button className={`${BUTTON[variant]} ${className}`} {...props} />;
}

// 밑줄형 입력 — 상자 없이 선 하나. 포커스하면 밑줄이 브랜드 색으로 굵어진다.
const FIELD = 'w-full border-0 border-b border-hairline bg-transparent px-1 py-2.5 outline-none transition-colors placeholder:text-ink-soft focus:border-b-2 focus:border-accent aria-invalid:border-accent-deep';
export function Input({ className = '', ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={`${FIELD} ${className}`} {...props} />;
}
// 여러 줄 입력은 밑줄만 두면 영역이 안 보인다 — 상자는 유지하되 포커스 강조는 같은 색으로
export function Textarea({ className = '', ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={`w-full min-h-23 resize-y rounded-lg border border-hairline bg-transparent px-4 py-2.5 outline-none transition-colors placeholder:text-ink-soft focus:border-accent aria-invalid:border-accent-deep ${className}`}
      {...props}
    />
  );
}

// 필드 아래 오류 한 줄 — 굵은 잉크 + ✗ (배너가 아니라 필드에 붙는 강조)
export function FieldError({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <p role="alert" className={`mt-1.5 text-[12.5px] font-bold text-ink ${className}`}>✗ {children}</p>;
}
