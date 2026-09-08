import Link from 'next/link';
import { Button, Input } from '@/components/ui';
import { ValidatedForm } from './ValidatedForm';
import { PasswordPair } from './PasswordPair';

const ERRORS: Record<string, string> = {
  password: 'Password must be at least 8 characters.',
  mismatch: 'Passwords do not match — check both fields.',
};

export async function ResetPage({ searchParams }: { searchParams: Promise<{ token?: string; error?: string }> }) {
  const { token = '', error } = await searchParams;
  return (
    <main className="mx-auto mt-16 max-w-100">
      <h1 className="font-display text-[28px] font-bold tracking-tight">Choose a new password</h1>
      {error && (
        <div role="alert" className="mt-4 rounded-lg border-l-4 border-ink bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          {ERRORS[error] ?? 'Something went wrong. Try again.'}
        </div>
      )}
      <div className="mt-5 rounded-2xl bg-surface p-5">
        <ValidatedForm action="/api/auth/reset">
          <input type="hidden" name="token" value={token} />
          <PasswordPair />
          <Button variant="blockPrimary">Set password</Button>
        </ValidatedForm>
      </div>
      <p className="mt-3 text-[13px] text-ink-soft">
        Link expired? <Link className="underline underline-offset-2" href="/forgot">Request a new one</Link>
      </p>
    </main>
  );
}
