'use client';
import { useEffect, useRef, useState } from 'react';
import { SubmitButton } from '@/components/SubmitButton';

export const ASK_DRAFT = 'poz_ask_draft';

/**
 * 질문 상자 — 이 사이트가 실제로 쓸모 있는 지점의 입구.
 *
 * 계정이 없어도 보낼 수 있다(/api/ask 가 게스트 행을 만든다). 답을 받아 본 뒤에 가입해서
 * 그 질문을 자기 것으로 가져간다 — 가치를 보기 전에 가입을 요구하면 아무도 가입하지 않는다.
 * 적던 질문(선택지까지)은 브라우저에 남겨 두어 실수로 새로고침해도 사라지지 않는다.
 * 초안은 보낼 때가 아니라 **글 페이지에 도착했을 때**(?asked=1, ClearDraft) 지운다 — 예전엔 제출 순간에 지워서
 * 서버가 429 로 돌려보내면 길게 쓴 고민이 사라졌다.
 * client_key: 같은 질문의 재시도(더블 클릭·새로고침)를 한 글로 묶는다.
 */
export function AskBox({ signedIn, verified, guest, seed = '' }: { signedIn: boolean; verified: boolean; guest: boolean; seed?: string }) {
  const [text, setText] = useState(seed);
  const [choices, setChoices] = useState<string[] | null>(null); // null = 투표 없음 (기본)
  const [restored, setRestored] = useState(false);
  const [clientKey, setClientKey] = useState('');
  const box = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    setClientKey(crypto.randomUUID()); // 마운트 뒤 — 서버 렌더에서 만들면 hydration 이 어긋난다
    try {
      const raw = localStorage.getItem(ASK_DRAFT);
      if (!raw || seed) return;
      // 옛 초안은 문자열, 새 초안은 {text, choices}
      const d = raw.startsWith('{') ? (JSON.parse(raw) as { text?: string; choices?: string[] | null }) : { text: raw };
      if (d.text) { setText(d.text); setRestored(true); }
      if (Array.isArray(d.choices) && d.choices.length) setChoices(d.choices);
    } catch { /* 저장소가 막힌 브라우저 */ }
  }, [seed]);

  const save = (t: string, c: string[] | null) => { try { localStorage.setItem(ASK_DRAFT, JSON.stringify({ text: t, choices: c })); } catch { /* noop */ } };
  const keep = (v: string) => { setText(v); save(v, choices); };
  const keepChoices = (c: string[] | null) => { setChoices(c); save(text, c); };
  const short = text.trim().length < 15;
  const blocked = signedIn && !guest && !verified;

  return (
    <div className="rounded-2xl bg-paper p-5 shadow-[0_1px_4px_rgba(0,0,0,0.05)] md:p-6">
      {restored && (
        <p role="status" className="mb-3 rounded-lg bg-surface-deep px-3 py-2 text-[13px] font-semibold">
          Still here from last time. Send it when you are ready.
        </p>
      )}
      <form method="post" action="/api/ask">
        <input type="hidden" name="client_key" value={clientKey} />
        <textarea
          ref={box}
          name="body"
          value={text}
          onChange={(e) => keep(e.target.value)}
          rows={5}
          maxLength={4000}
          placeholder={'What do you actually want to know?\n\nex) "is $250 fair for a used 3070, bought in 2021, seller says no mining" · "is this clause normal in a lease?" · "eggs, cold rice, half an onion. what do I make?"'}
          className="w-full resize-y rounded-xl border border-hairline bg-surface p-4 text-[15px] leading-relaxed outline-none placeholder:text-ink-faint focus:border-ink"
        />
        {/* 결정을 물을 때는 선택지를 붙인다 — 답만 오는 게 아니라 표도 쌓인다 */}
        {choices === null ? (
          <button type="button" onClick={() => keepChoices(['', ''])} className="mt-2 text-[12.5px] font-bold text-ink-soft underline underline-offset-2 hover:text-ink">
            Deciding between things? Add options to vote on
          </button>
        ) : (
          <div className="mt-3 rounded-xl border border-hairline bg-surface p-3">
            <p className="mb-2 text-[12px] font-bold uppercase tracking-widest text-ink-soft">Options to vote on</p>
            {choices.map((c, i) => (
              <input
                key={i}
                name="option"
                value={c}
                maxLength={60}
                onChange={(e) => keepChoices(choices.map((x, j) => (j === i ? e.target.value : x)))}
                placeholder={i === 0 ? 'e.g. buy the used one' : i === 1 ? 'e.g. save up for new' : 'another option'}
                aria-label={`Option ${i + 1}`}
                className="mt-1.5 w-full rounded-lg border border-hairline bg-paper px-3 py-2 text-[14px] outline-none focus:border-ink"
              />
            ))}
            <div className="mt-2 flex gap-3 text-[12px] font-bold">
              {choices.length < 4 && <button type="button" onClick={() => keepChoices([...choices, ''])} className="text-ink-soft underline underline-offset-2 hover:text-ink">Add another</button>}
              <button type="button" onClick={() => keepChoices(null)} className="text-ink-soft underline underline-offset-2 hover:text-ink">Remove options</button>
            </div>
          </div>
        )}
        <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
          <p className="text-[12.5px] text-ink-soft">
            {blocked
              ? <>Verify your email first, check your inbox or <a className="underline underline-offset-2" href="/me">resend it</a>.</>
              : signedIn && !guest
                ? 'Answers start arriving in about a minute.'
                : 'No account needed. Answers arrive in about a minute; sign up afterwards to keep the thread.'}
          </p>
          <SubmitButton variant="primary" pendingLabel="Sending…" disabled={short || blocked}>Ask</SubmitButton>
        </div>
      </form>
    </div>
  );
}
