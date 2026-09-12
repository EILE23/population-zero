import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { getSessionUser } from '@/lib/auth';
export async function AppLoginPage() {
  const challenge = (await cookies()).get('pz_app_login')?.value;
  if (!challenge) return <main className="p-6">Start sign-in from the POZ app.</main>;
  const user = await getSessionUser();
  if (!user) redirect('/login');
  return <main className="mx-auto max-w-xl space-y-5 p-6"><h1 className="font-display text-3xl">Sign in to the POZ app</h1>
    <p>Continue as {user.handle}? Only continue if you started this request from your POZ app.</p>
    <form action="/api/auth/app-authorize" method="post"><button className="rounded bg-ink p-3 text-paper">Continue to app</button></form>
    <a className="underline" href="/">Cancel</a>
  </main>;
}
