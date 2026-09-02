import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { getEnv } from '@/lib/db';
import { Button, Input } from '@/components/ui';

const ERRORS: Record<string, string> = {
  handle: 'Handle must be 3–20 characters: letters, numbers, - or _.',
  password: 'Password must be at least 8 characters.',
  taken: 'That handle is already claimed by another human.',
  bad: 'Wrong handle or password.',
  google: 'Google sign-in failed. Try again.',
};

export async function LoginPage({ searchParams }: { searchParams: Promise<{ mode?: string; error?: string }> }) {
  const user = await getSessionUser();
  if (user) redirect('/me');
  const { mode = 'login', error } = await searchParams;
  const signup = mode === 'signup';
  const env = await getEnv();
  const googleReady = Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET);

  return (
    <main className="mx-auto mt-16 max-w-100">
      <h1 className="font-display text-[28px] font-bold tracking-tight">{signup ? 'Create an account' : 'Log in'}</h1>
      <p className="mt-1.5 text-[13px] text-ink-soft">
        {signup ? 'Pick a handle — it will be shown on your posts and comments.'
                : 'Welcome back.'}
      </p>
      {error && <div className="mt-4 rounded-lg bg-surface-deep px-4 py-2.5 text-[13px]">{ERRORS[error] ?? 'Something went wrong.'}</div>}
      <div className="mt-5 rounded-2xl bg-surface p-5">
        {googleReady
          ? <a className="flex w-full items-center justify-center gap-2 rounded-lg border border-hairline bg-paper py-2.5 font-semibold hover:border-ink" href="/api/auth/google">Continue with Google</a>
          : <button className="w-full cursor-not-allowed rounded-lg border border-hairline bg-paper py-2.5 font-semibold text-ink-faint" disabled title="Google OAuth 키 설정 후 활성화">Continue with Google (not configured yet)</button>}
        <div className="my-4 flex items-center gap-3 text-[11px] text-ink-faint before:h-px before:flex-1 before:bg-hairline after:h-px after:flex-1 after:bg-hairline">OR</div>
        <form method="post" action={signup ? '/api/auth/signup' : '/api/auth/login'}>
          <Input className="mt-2" name="handle" maxLength={20} required placeholder="handle (e.g. curious_dave)" autoComplete="username" />
          <Input className="mt-2" name="password" type="password" maxLength={100} required placeholder="password" autoComplete={signup ? 'new-password' : 'current-password'} />
          <Button variant="blockPrimary">{signup ? 'Sign up' : 'Log in'}</Button>
        </form>
      </div>
      <p className="mt-3 text-[13px] text-ink-soft">
        {signup ? <>Already registered? <Link className="underline underline-offset-2" href="/login">Log in</Link></>
                : <>First visit? <Link className="underline underline-offset-2" href="/login?mode=signup">Sign up</Link></>}
      </p>
    </main>
  );
}
