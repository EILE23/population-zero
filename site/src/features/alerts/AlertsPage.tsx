import Link from 'next/link';
import { getSessionUser } from '@/lib/auth';
import { getDb } from '@/lib/db';
import { AlertsManager } from './components/AlertsManager';
import { SignUpCta } from './components/SignUpCta';

interface AlertRow { id: number; keyword: string; region: string; created_at: string }

/**
 * /alerts — 계정이 있어야 쓸 수 있고, 계정이 있으면 실제로 쓸 일이 있는 기능.
 *
 * 순찰이 하루 여덟 번 12개국 언론을 모은다. 여기서 사람은 단어를 걸어 두고, 그 단어가 기사에 뜨면 메일을 받는다.
 * 모델을 부르지 않는다 — 수집은 이미 돌고 있고, 여기는 문자열 매칭과 발송뿐이다.
 * 로그아웃 상태로도 페이지는 보인다(색인·가입 유도). 단어를 걸려면 메일 주소가 필요하니 거기서 가입으로 간다.
 */
export async function AlertsPage() {
  const user = await getSessionUser();
  const db = await getDb();
  const signedIn = !!user && !user.guest;

  const [alerts, prefs, counts] = await Promise.all([
    signedIn
      ? db.prepare(`SELECT id, keyword, region, created_at FROM alerts WHERE user_id = ? ORDER BY created_at DESC`)
        .bind(user.id).all<AlertRow>().then((r) => r.results)
      : Promise.resolve([] as AlertRow[]),
    signedIn
      ? db.prepare(`SELECT email_brief, brief_region, email_optout FROM users WHERE id = ?`).bind(user.id)
        .first<{ email_brief: number; brief_region: string | null; email_optout: number }>()
      : Promise.resolve(null),
    db.prepare(`SELECT COUNT(*) AS stories, COUNT(DISTINCT region) AS regions FROM trends
                WHERE kind = 'news' AND collected_at > datetime('now','-1 day')`)
      .first<{ stories: number; regions: number }>(),
  ]);

  return (
    <main className="mx-auto mt-8 max-w-180 px-4 pb-20 sm:mt-12">
      <p className="font-mono text-[11.5px] uppercase tracking-[0.14em] text-ink-soft">Alerts</p>
      <h1 className="mt-2 font-display text-[30px] font-bold leading-tight tracking-tight sm:text-[38px]">
        Tell us a word. We&apos;ll mail you when the press uses it.
      </h1>
      <p className="mt-3 max-w-150 text-[15px] leading-relaxed text-ink-mid">
        Every day we read {(counts?.stories ?? 0).toLocaleString()} stories from{' '}
        {counts?.regions ?? 12} countries&apos; press — the local outlets too, not only the English ones.
        A company name, a bill, a game, your own name: one email when it turns up, nothing when it doesn&apos;t.
      </p>

      {signedIn ? (
        <div className="mt-8">
          <AlertsManager
            initial={alerts}
            brief={prefs?.email_brief === 1 && prefs?.email_optout !== 1}
            briefRegion={prefs?.brief_region ?? ''}
          />
          <p className="mt-6 text-[13px] text-ink-soft">
            Emails stop from the link at the bottom of any of them, or from{' '}
            <Link className="underline underline-offset-2 hover:text-ink" href="/me">your account page</Link>.
          </p>
        </div>
      ) : (
        <div className="mt-8 rounded-2xl border border-hairline bg-paper p-6">
          <p className="text-[15px] font-semibold">Alerts arrive by email, so this one needs an account.</p>
          <p className="mt-1.5 text-[13.5px] text-ink-mid">Free, no card, and you can watch 20 words.</p>
          <SignUpCta />
        </div>
      )}

      <div className="mt-10 border-t border-hairline pt-6 text-[13.5px] leading-relaxed text-ink-mid">
        <p><strong className="font-semibold text-ink">Where the stories come from.</strong> Public feeds and official APIs from twelve countries, collected eight times a day. We link out to the publisher — we never reprint the article.</p>
        <p className="mt-2.5"><strong className="font-semibold text-ink">How often it mails.</strong> At most once an hour, and only when something actually matched. The morning brief is one a day.</p>
      </div>
    </main>
  );
}
