'use client';
import { useState } from 'react';

/**
 * 메일 설정 — 스위치 두 개.
 *  · answers: 내가 물어본 글에 답이 달리면 알린다 (내 글에 대한 것이라 기본 켜짐)
 *  · weekly : 마케팅 수신 동의 (제품 소식·추천 글, 주 1회 수준) — 명시 동의만 켠다
 * 누르는 즉시 저장한다 — 설정 화면에 저장 버튼이 또 있는 건 사람을 한 번 더 붙잡아 두는 짓이다.
 */
export function EmailSettings({ answers, weekly }: { answers: boolean; weekly: boolean }) {
  const [state, setState] = useState({ answers, weekly });
  const [saved, setSaved] = useState<'idle' | 'saving' | 'ok' | 'fail'>('idle');

  async function toggle(key: 'answers' | 'weekly') {
    const next = { ...state, [key]: !state[key] };
    setState(next); setSaved('saving');
    const res = await fetch('/api/me/email-prefs', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(next),
    });
    setSaved(res.ok ? 'ok' : 'fail');
    if (!res.ok) setState(state);
  }

  const Row = ({ k, title, sub }: { k: 'answers' | 'weekly'; title: string; sub: string }) => (
    <label className="flex cursor-pointer items-start gap-3 border-b border-hairline py-3 last:border-0">
      <input type="checkbox" checked={state[k]} onChange={() => void toggle(k)} className="mt-1 size-4 accent-[var(--accent)]" />
      <span>
        <span className="block text-[14px] font-semibold">{title}</span>
        <span className="block text-[12.5px] text-ink-soft">{sub}</span>
      </span>
    </label>
  );

  return (
    <div className="rounded-xl bg-paper p-4 shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
      <Row k="answers" title="Answers to my questions" sub="When residents answer something you posted. Off means you only see it if you come back." />
      <Row k="weekly" title="Marketing emails" sub="Product updates, recommended reads and occasional news. About once a week, never more." />
      <p className="mt-2 text-[12px] text-ink-soft">{saved === 'saving' ? 'Saving…' : saved === 'ok' ? 'Saved.' : saved === 'fail' ? 'Could not save, try again.' : ''}</p>
    </div>
  );
}
