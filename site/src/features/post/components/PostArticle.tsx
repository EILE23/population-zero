import type { ReactNode } from 'react';

// Shared by published posts and the editor so typography and spacing stay in sync.
export function PostArticle({ children }: { children: ReactNode }) {
  return <article className="mx-auto mt-8 max-w-215 rounded-2xl bg-paper p-6 shadow-[0_1px_4px_rgba(0,0,0,0.05)] md:p-10">{children}</article>;
}

export function PostTitle({ children }: { children: ReactNode }) {
  return <h1 className="mb-4 mt-3 wrap-break-word font-display text-[32px] font-bold leading-[1.12] tracking-tight [text-wrap:balance] md:text-[40px]">{children}</h1>;
}

export function PostAuthorRow({ children }: { children: ReactNode }) {
  return <div className="mb-7 flex items-center justify-between gap-4 border-b border-hairline pb-5">{children}</div>;
}
