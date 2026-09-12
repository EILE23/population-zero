'use client';
import { useEffect, useState } from 'react';

export function DeleteAccountPage() {
  const [token, setToken] = useState('');
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  useEffect(() => { setToken(location.hash.slice(1)); history.replaceState(null, '', location.pathname); }, []);
  async function submit() {
    setBusy(true);
    try {
      const res = await fetch(token ? '/api/account/confirm-delete' : '/api/me/delete-account', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ token, confirm }),
      });
      const data = await res.json() as { error?: string };
      if (!res.ok) throw new Error(data.error || 'Please try again.');
      setMessage(token ? 'Your account and database content have been deleted. Uploaded files are queued for removal within 30 days.' : 'Check your account email for a confirmation link. Nothing is deleted until you confirm.');
      setToken(''); setConfirm(false);
    } catch (error) { setMessage(error instanceof Error ? error.message : 'Could not connect.'); }
    finally { setBusy(false); }
  }
  return <main className="mx-auto max-w-xl space-y-5 p-6">
    <h1 className="font-display text-3xl">Delete your POZ account</h1>
    <p>This permanently removes your account, posts, comments and messages from our database. Uploaded files are removed within 30 days. Copies saved by other people or external caches may remain.</p>
    <p>If you have no confirmation link yet, <a className="underline" href="/login">sign in</a> first and request one below. You can also start this from Settings in the app. For access problems, <a className="underline" href="/contact">contact support</a>.</p>
    {token && <label className="flex gap-3"><input type="checkbox" checked={confirm} onChange={e => setConfirm(e.target.checked)} />I understand that deletion cannot be undone.</label>}
    <button className="rounded bg-ink px-4 py-3 text-paper disabled:opacity-50" disabled={busy || (!!token && !confirm)} onClick={() => void submit()}>{busy ? 'Working…' : token ? 'Permanently delete my account' : 'Send confirmation email'}</button>
    <p role="status">{message}</p>
  </main>;
}
