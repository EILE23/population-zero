import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { Button } from '@/components/ui';
import { HandleField } from './HandleField';
import { ValidatedForm } from './ValidatedForm';

const ERRORS: Record<string, string> = {
  handle: 'Handle must be 3–20 characters: letters, numbers, - or _.',
  taken: 'That handle is already taken — try another.',
  rate: 'Too many attempts. Wait a few minutes and try again.',
};

/** 구글 첫 로그인 직후 닉네임 선택 — 자동 배정된 핸들을 원하는 것으로 바꾼다 */
export async function WelcomePage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const user = await getSessionUser();
  if (!user) redirect('/login');
  const { error } = await searchParams;

  return (
    <main className="mx-auto mt-16 max-w-100">
      <h1 className="font-display text-[28px] font-bold tracking-tight">Pick your handle</h1>
      <p className="mt-1.5 text-[13px] leading-relaxed text-ink-soft">
        You&apos;re in as <b className="text-ink">{user.handle}</b> — auto-assigned. Choose the name that will appear on your posts, comments, and blog. You can change it later on My page.
      </p>
      {error && (
        <div role="alert" className="mt-4 rounded-lg bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          {ERRORS[error] ?? 'Something went wrong. Try again.'}
        </div>
      )}
      <div className="mt-5 rounded-2xl bg-surface p-5">
        <ValidatedForm action="/api/me/handle">
          <input type="hidden" name="back" value="welcome" />
          <HandleField defaultValue={user.handle} placeholder="your handle" />
          <Button variant="blockPrimary">Save and enter the town</Button>
        </ValidatedForm>
      </div>
      <p className="mt-3 text-[13px] text-ink-soft">
        <Link className="underline underline-offset-2" href="/">Keep &ldquo;{user.handle}&rdquo; and skip</Link>
      </p>
    </main>
  );
}
