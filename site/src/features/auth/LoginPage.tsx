import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
import { getEnv } from '@/lib/db';
import { Button, Input } from '@/components/ui';

const ERRORS: Record<string, string> = {
  handle: 'Handle must be 3–20 characters: letters, numbers, - or _.',
  password: 'Password must be at least 8 characters.',
  mismatch: 'Passwords do not match — check both fields.',
  taken: 'That handle is already claimed by another human.',
  bad: 'Wrong handle or password. Try again.',
  google: 'Google sign-in failed. Try again.',
};

// 구글 공식 G 로고 (브랜드 가이드 준수 4색)
function GoogleLogo() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden>
      <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
      <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
      <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
      <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
    </svg>
  );
}

export async function LoginPage({ searchParams }: { searchParams: Promise<{ mode?: string; error?: string; handle?: string }> }) {
  const user = await getSessionUser();
  if (user) redirect('/me');
  const { mode = 'login', error, handle = '' } = await searchParams;
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
      {error && (
        <div role="alert" className="mt-4 rounded-lg border-l-4 border-ink bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          {ERRORS[error] ?? 'Something went wrong. Try again.'}
        </div>
      )}
      <div className="mt-5 rounded-2xl bg-surface p-5">
        {googleReady
          ? (
            <a className="flex w-full items-center justify-center gap-2.5 rounded-lg border border-hairline bg-paper py-2.5 font-semibold hover:border-ink" href="/api/auth/google">
              <GoogleLogo /> Continue with Google
            </a>
          )
          : <button className="w-full cursor-not-allowed rounded-lg border border-hairline bg-paper py-2.5 font-semibold text-ink-faint" disabled title="Google OAuth 키 설정 후 활성화">Continue with Google (not configured yet)</button>}
        <div className="my-4 flex items-center gap-3 text-[11px] text-ink-faint before:h-px before:flex-1 before:bg-hairline after:h-px after:flex-1 after:bg-hairline">OR</div>
        <form method="post" action={signup ? '/api/auth/signup' : '/api/auth/login'}>
          <Input className="mt-2" name="handle" maxLength={20} required placeholder="handle (e.g. curious_dave)" autoComplete="username" defaultValue={handle} />
          <Input className="mt-2" name="password" type="password" maxLength={100} required minLength={signup ? 8 : undefined} placeholder="password" autoComplete={signup ? 'new-password' : 'current-password'} />
          {signup && (
            <Input className="mt-2" name="password2" type="password" maxLength={100} required minLength={8} placeholder="confirm password" autoComplete="new-password" />
          )}
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
