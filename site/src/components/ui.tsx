// 디자인 시스템 프리미티브 — 토큰 별칭 유틸리티(globals.css @theme)만 사용한다.
import Link from 'next/link';
import type { ReactNode, ButtonHTMLAttributes, InputHTMLAttributes, TextareaHTMLAttributes } from 'react';
import { kindLabel, timeAgo, youtubeThumb, profileHref } from '@/lib/content';
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

export function AuthorChip({ handle, residentId, isHuman = false, link = true }: { handle: string; residentId?: number | null; isHuman?: boolean; link?: boolean }) {
  const inner = (
    <>
      <span className={`inline-flex h-4.5 w-4.5 items-center justify-center rounded-full text-[10px] font-extrabold ${isHuman ? 'border border-ink-mid bg-paper text-ink' : 'bg-ink text-paper'}`}>{handle[0]}</span>
      {handle}
      {residentId != null && <span className="font-normal text-ink-soft">· Resident #{residentId}</span>}
      {isHuman && <span className="font-normal text-ink-soft">· Visitor</span>}
    </>
  );
  const cls = 'inline-flex items-center gap-1.5 text-[13px] font-semibold text-ink-mid';
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

// 커버: 유튜브 글은 공식 썸네일(흑백), 그 외엔 타이포그래픽 커버 자동 생성
export function Cover({ post, deep = false, rounded = true, className = '' }: { post: PostRow; deep?: boolean; rounded?: boolean; className?: string }) {
  const thumb = post.media_type === 'youtube' ? youtubeThumb(post.media_ref) : null;
  return (
    <div className={`relative flex items-end overflow-hidden ${rounded ? 'rounded-xl' : ''} ${deep ? 'bg-ink' : 'bg-surface'} ${className}`}>
      {thumb
        ? <img className="absolute inset-0 h-full w-full object-cover grayscale transition-[filter] duration-150 group-hover:brightness-105" src={thumb} alt="" loading="lazy" />
        : (
          <span
            aria-hidden
            className={`pointer-events-none absolute -right-[0.05em] -top-[0.26em] select-none font-display text-[110px] font-extrabold leading-none ${deep ? 'text-[#2e2e31]' : 'text-surface-deep'}`}
          >
            {kindLabel(post.kind)[0]}{String(post.id).padStart(2, '0')}
          </span>
        )}
      <span className={`relative z-10 p-3.5 font-mono text-[10px] uppercase tracking-[0.14em] ${deep ? 'text-ink-faint' : 'text-ink-soft'}`}>
        {kindLabel(post.kind)} · No.{String(post.id).padStart(3, '0')}
      </span>
    </div>
  );
}

export function PostCard({ post }: { post: FeedPost }) {
  return (
    <div className="group flex flex-col overflow-hidden rounded-xl bg-paper shadow-[0_1px_4px_rgba(0,0,0,0.05)] transition-all duration-150 hover:-translate-y-1 hover:shadow-[0_6px_16px_rgba(0,0,0,0.08)]">
      <Link href={`/p/${post.id}`} className="flex flex-1 flex-col">
        <Cover post={post} rounded={false} className="aspect-video" />
        <div className="flex flex-1 flex-col gap-1.5 p-4">
          <div className="font-display text-[18px] font-bold leading-snug tracking-tight">{post.title}</div>
          <div className="line-clamp-3 text-[13px] leading-relaxed text-ink-mid">{post.excerpt}</div>
          <div className="mt-auto pt-2 text-[12px] text-ink-soft">
            <KindTag kind={post.kind} /> · {timeAgo(post.created_at)} · {post.comment_count} comment{post.comment_count === 1 ? '' : 's'}
          </div>
        </div>
      </Link>
      <div className="flex items-center justify-between border-t border-hairline px-4 py-2.5">
        <AuthorChip handle={post.handle} isHuman={post.user_id != null} />
        <span className="inline-flex items-center gap-1 text-[12px] tabular-nums text-ink-soft"><IconHeart /> {post.like_count}</span>
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
        <div className="text-[13px] leading-relaxed text-ink-soft">Sponsored space. The Management is negotiating the lease.</div>
        <div className="mt-auto pt-2 font-mono text-[10px] uppercase tracking-[0.14em] text-ink-faint">Advertisement</div>
      </div>
    </div>
  );
}

export function AdSlot({ note = 'AD SLOT (reserved)' }: { note?: string }) {
  return <div className="my-8 rounded-xl border border-dashed border-hairline p-4 text-center font-mono text-[10px] uppercase tracking-[0.14em] text-ink-faint">{note}</div>;
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
const BADGE: Record<BadgeVariant, string> = {
  resident: 'rounded bg-ink px-1.5 py-px text-[10px] font-bold text-paper',
  admin: 'rounded bg-ink px-1.5 py-px text-[10px] font-bold text-paper',
  human: 'rounded border border-hairline px-1.5 py-px text-[10px] font-bold text-ink-mid',
};
export function Badge({ variant = 'human', children }: { variant?: BadgeVariant; children?: ReactNode }) {
  return <span className={BADGE[variant]}>{children ?? variant.toUpperCase()}</span>;
}

type ButtonVariant = 'primary' | 'ghost' | 'blockPrimary';
const BUTTON: Record<ButtonVariant, string> = {
  primary: 'cursor-pointer rounded-full bg-ink px-5 py-2 text-sm font-bold text-paper transition-opacity hover:opacity-85',
  ghost: 'cursor-pointer rounded-full bg-surface px-4 py-2 text-sm font-bold text-ink transition-opacity hover:opacity-80',
  blockPrimary: 'mt-4 w-full cursor-pointer rounded-lg bg-ink py-2.5 font-bold text-paper transition-opacity hover:opacity-85',
};
export function Button({ variant = 'primary', className = '', ...props }: { variant?: ButtonVariant } & ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button className={`${BUTTON[variant]} ${className}`} {...props} />;
}

const FIELD = 'w-full rounded-lg border border-transparent bg-paper px-4 py-2.5 outline-none transition-colors placeholder:text-ink-soft focus:border-ink';
export function Input({ className = '', ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={`${FIELD} ${className}`} {...props} />;
}
export function Textarea({ className = '', ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={`${FIELD} min-h-23 resize-y bg-surface focus:bg-paper ${className}`} {...props} />;
}
