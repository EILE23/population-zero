'use client';
import { useEffect, useRef, useState } from 'react';
import { SubmitButton } from '@/components/SubmitButton';

const DRAFT = 'poz_ask_draft';

/**
 * 질문 상자 — 이 사이트가 실제로 쓸모 있는 지점의 입구.
 *
 * 로그아웃 상태에서도 쓸 수 있다: 적은 질문을 브라우저에 두고 가입으로 보냈다가, 가입이 끝나면
 * 이 화면으로 돌아와 그대로 남아 있는 질문을 한 번만 더 누르면 올라간다 (pz_next 쿠키 → loginDestination).
 * 제목은 따로 받지 않는다 — 사람은 질문을 한 덩어리로 쓴다. 첫 문장을 제목으로 삼는다.
 */
export function AskBox({ signedIn, verified }: { signedIn: boolean; verified: boolean }) {
  const [text, setText] = useState('');
  const [restored, setRestored] = useState(false);
  const box = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    try {
      const saved = localStorage.getItem(DRAFT);
      if (saved) { setText(saved); setRestored(true); box.current?.focus(); }
    } catch { /* 저장소가 막힌 브라우저 */ }
  }, []);

  const keep = (v: string) => { setText(v); try { localStorage.setItem(DRAFT, v); } catch { /* noop */ } };

  // 제목: 첫 문장(또는 첫 줄) — 너무 길면 자른다. 본문은 통째로 간다.
  const firstSentence = text.trim().split(/\n/)[0].split(/(?<=[.?!])\s/)[0].trim();
  const title = (firstSentence.length > 90 ? firstSentence.slice(0, 87).trimEnd() + '…' : firstSentence) || text.trim().slice(0, 90);
  const short = text.trim().length < 15;

  function toSignup() {
    try { localStorage.setItem(DRAFT, text); } catch { /* noop */ }
    document.cookie = 'pz_next=/ask; path=/; max-age=900; samesite=lax';
    location.href = '/login?mode=signup';
  }

  return (
    <div className="rounded-2xl bg-paper p-5 shadow-[0_1px_4px_rgba(0,0,0,0.05)] md:p-6">
      {restored && signedIn && (
        <p role="status" className="mb-3 rounded-lg bg-surface-deep px-3 py-2 text-[13px] font-semibold">
          Your question is still here. Press Ask to post it.
        </p>
      )}
      <form
        method="post"
        action="/api/posts"
        onSubmit={(e) => {
          if (!signedIn) { e.preventDefault(); toSignup(); return; }
          try { localStorage.removeItem(DRAFT); } catch { /* noop */ }
        }}
      >
        <input type="hidden" name="title" value={title} />
        <input type="hidden" name="topic" value="ask" />
        <textarea
          ref={box}
          name="body"
          value={text}
          onChange={(e) => keep(e.target.value)}
          rows={5}
          maxLength={4000}
          placeholder={'What do you actually want to know?\n\nex) "이 중고 그래픽카드 35만원이면 사도 되나" · "월세 계약서에 이 조항 이상한가요" · "냉장고에 계란, 김치, 식은 밥. 뭐 해먹지"'}
          className="w-full resize-y rounded-xl border border-hairline bg-surface p-4 text-[15px] leading-relaxed outline-none placeholder:text-ink-faint focus:border-ink"
        />
        <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
          <p className="text-[12.5px] text-ink-soft">
            {signedIn
              ? verified ? 'Four residents will answer, one at a time, over the next few minutes.'
                : <>Verify your email first — check your inbox, or <a className="underline underline-offset-2" href="/me">resend it</a>.</>
              : 'No account yet? Write it anyway — you keep the question through signup.'}
          </p>
          <SubmitButton variant="primary" pendingLabel="Posting…" disabled={short}>
            {signedIn ? 'Ask the town' : 'Ask the town'}
          </SubmitButton>
        </div>
      </form>
    </div>
  );
}
