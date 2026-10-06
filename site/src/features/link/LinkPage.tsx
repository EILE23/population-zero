import Link from 'next/link';
import { getSessionUser } from '@/lib/auth';
import { normalizeCode } from '@/lib/game-link';
import { LoginLink } from '@/components/LoginLink';

/**
 * /link — POZ 클라이언트(데스크톱 게임)를 이 계정에 연결한다. 게임이 브라우저로 이 페이지를 연다(?code=).
 * 로그인했으면 Connect 한 번, 아니면 로그인하고 이 자리로 돌아온다(LoginLink → pz_next).
 * 남이 보낸 링크로 남의 게임에 내 계정을 넘기는 일을 막으려고 "지금 게임 화면에 이 코드가 보일 때만" 이라고 적는다.
 */
export async function LinkPage({ code, done, error }: { code?: string; done?: boolean; error?: string }) {
  const user = await getSessionUser();
  const c = normalizeCode(code ?? '');
  return (
    <main className="mx-auto mt-10 max-w-[560px]">
      <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">POZ · this computer</p>
      {done ? (
        <>
          <h1 className="mt-1.5 font-display text-[28px] font-bold tracking-tight">Connected.</h1>
          <p className="mt-2 text-[14px] text-ink-mid">Go back to the game. It signs in within a few seconds. You can close this tab.</p>
        </>
      ) : (
        <>
          <h1 className="mt-1.5 font-display text-[28px] font-bold tracking-tight">Connect the game to your account</h1>
          {error === 'expired' && <p className="mt-3 text-[13.5px] text-accent">That code has expired or was already used. Press S in the game for a new one.</p>}
          {error === 'code' && <p className="mt-3 text-[13.5px] text-accent">That does not look like a game code.</p>}
          {!user || user.guest ? (
            <p className="mt-3 text-[14px] text-ink-mid">
              <LoginLink className="font-bold text-accent underline underline-offset-2">Log in</LoginLink> first; you come back here after.
            </p>
          ) : (
            <form action="/api/game/link/approve" method="post" className="mt-5 grid gap-4">
              <label className="grid gap-1.5">
                <span className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">Code shown in the game</span>
                <input name="code" defaultValue={c ?? ''} required autoComplete="off" spellCheck={false} className="w-full rounded-lg border border-hairline bg-surface px-3 py-2.5 font-mono text-[22px] tracking-[0.2em] text-ink" />
              </label>
              <p className="text-[13px] text-ink-mid">Continue only if this code is on your game screen right now. Someone who sends you a code can use it to play as you.</p>
              <div className="flex items-center gap-4">
                <button type="submit" className="rounded-full border-2 border-ink px-6 py-2 font-mono text-[13px] font-bold uppercase tracking-[0.14em] text-ink hover:bg-ink hover:text-paper">Connect as {user.handle}</button>
                <Link href="/" className="text-[13px] text-ink-soft underline underline-offset-2">Cancel</Link>
              </div>
            </form>
          )}
        </>
      )}
    </main>
  );
}
