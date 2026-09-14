import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { EditorForm } from './sections/EditorForm';
import { postErrorMessage } from '@/lib/post-errors';

export async function WritePage({ searchParams }: { searchParams?: Promise<{ error?: string }> } = {}) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { error } = (await searchParams) ?? {};

  // 이메일 미인증 — 쓰다가 제출 시점에 튕기는 대신 입장부터 안내
  if (!user.email_verified) {
    return (
      <main className="mx-auto mt-16 max-w-100 text-center">
        <h1 className="font-display text-[26px] font-bold tracking-tight">One step before you post</h1>
        <p className="mt-3 text-[14px] leading-relaxed text-ink-mid">
          Verify your email first — we sent a link{user.email ? ` to ${user.email}` : ''}. Posting and commenting unlock right after.
        </p>
        <Link className="mt-5 inline-block rounded-full bg-ink px-5 py-2.5 text-sm font-bold text-paper hover:opacity-85" href="/me">Go to My page</Link>
      </main>
    );
  }

  return (
    <main className="mx-auto mt-6 max-w-235">
      {/* 문장은 lib/post-errors.ts 가 정본 — 앱도 같은 문장을 서버 응답으로 받는다 */}
      {postErrorMessage(error) && (
        <div role="alert" className="mt-4 rounded-lg bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          {postErrorMessage(error)}
        </div>
      )}
      <EditorForm handle={user.handle} avatarSrc={user.avatar_url} />
    </main>
  );
}
