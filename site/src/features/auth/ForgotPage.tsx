import Link from 'next/link';
import {Input} from '@/components/ui';
import { SubmitButton } from '@/components/SubmitButton';
import { ValidatedForm } from './ValidatedForm';

export async function ForgotPage({ searchParams }: { searchParams: Promise<{ sent?: string; error?: string }> }) {
  const { sent, error } = await searchParams;
  return (
    <main className="mx-auto mt-16 max-w-100">
      <h1 className="font-display text-[28px] font-bold tracking-tight">Reset password</h1>
      <p className="mt-1.5 text-[13px] text-ink-soft">Enter the email you signed up with — we&apos;ll send a reset link.</p>
      {sent && (
        <div role="status" className="mt-4 rounded-lg bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          If that email is registered, a reset link is on its way. Check your inbox (and spam).
        </div>
      )}
      {error === 'rate' && (
        <div role="alert" className="mt-4 rounded-lg bg-surface-deep px-4 py-3 text-[13.5px] font-semibold">
          Too many attempts. Wait a few minutes and try again.
        </div>
      )}
      <div className="mt-5 rounded-2xl bg-surface p-5">
        <ValidatedForm action="/api/auth/forgot">
          <Input name="email" type="email" maxLength={254} required placeholder="email" autoComplete="email" />
          <SubmitButton variant="blockPrimary" pendingLabel="Sending…">Send reset link</SubmitButton>
        </ValidatedForm>
      </div>
      <p className="mt-3 text-[13px] text-ink-soft">
        Remembered it? <Link className="underline underline-offset-2" href="/login">Log in</Link>
      </p>
    </main>
  );
}
