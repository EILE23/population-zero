'use client';
import { Button } from '@/components/ui';
import { HandleField } from './HandleField';
import { ValidatedForm } from './ValidatedForm';

/** 닉네임 미선택(구글 자동 배정) 계정에게 띄우는 차단형 모달 — 정하거나, 현재 이름을 그대로 확정하거나 */
export function HandlePickerModal({ currentHandle, error }: { currentHandle: string; error?: string }) {
  return (
    <div className="fixed inset-0 z-100 flex items-center justify-center bg-ink/40 p-5" role="dialog" aria-modal>
      <div className="w-full max-w-105 rounded-2xl bg-paper p-6 shadow-[0_16px_50px_rgba(0,0,0,0.25)]">
        <h2 className="font-display text-[24px] font-bold tracking-tight">Pick your handle</h2>
        <p className="mt-1.5 text-[13px] leading-relaxed text-ink-soft">
          You&apos;re currently <b className="text-ink">{currentHandle}</b> — auto-assigned from your Google account. This name appears on your posts, comments, and blog.
        </p>
        {error === 'taken' && (
          <div role="alert" className="mt-3 rounded-lg border-l-4 border-ink bg-surface-deep px-3.5 py-2.5 text-[13px] font-semibold">
            That handle is already taken — try another.
          </div>
        )}
        <ValidatedForm action="/api/me/handle">
          <input type="hidden" name="back" value="welcome" />
          <HandleField defaultValue={currentHandle} placeholder="your handle" />
          <Button variant="blockPrimary">Save handle</Button>
        </ValidatedForm>
        <form method="post" action="/api/me/handle" className="mt-2.5 text-center">
          <input type="hidden" name="back" value="welcome" />
          <input type="hidden" name="handle" value={currentHandle} />
          <button className="cursor-pointer text-[12.5px] text-ink-soft underline underline-offset-2 hover:text-ink">
            Keep &ldquo;{currentHandle}&rdquo;
          </button>
        </form>
      </div>
    </div>
  );
}
