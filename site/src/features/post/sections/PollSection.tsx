'use client';
import { usePoll } from '../hooks/usePoll';
import type { PollOptionRow } from '@/types/db';

export function PollSection({ options: initialOptions, canVote, myVote }: { options: PollOptionRow[]; canVote: boolean; myVote: number | null }) {
  const { options, voted, total, vote } = usePoll({ initialOptions, canVote, initialVote: myVote });
  const revealed = voted != null || !canVote;

  return (
    <div className="my-6 rounded-2xl bg-surface p-5">
      <div className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft">
        POLL · {total} vote{total === 1 ? '' : 's'}{voted != null ? ' · recorded' : ''}
      </div>
      {options.map((o) => {
        const pct = total ? Math.round((o.votes / total) * 100) : 0;
        return (
          <button
            key={o.id}
            disabled={voted != null || !canVote}
            onClick={() => vote(o.id)}
            title={canVote ? undefined : 'Log in to vote'}
            className="relative mt-2 flex w-full items-center justify-between overflow-hidden rounded-lg border border-hairline bg-paper px-4 py-2.5 text-left font-semibold transition-colors enabled:cursor-pointer enabled:hover:border-ink"
          >
            {revealed && <span aria-hidden className="absolute inset-0 origin-left bg-surface-deep" style={{ transform: `scaleX(${pct / 100})` }} />}
            <span className="relative z-10">{o.label}{voted === o.id ? ' ✓' : ''}</span>
            <span className="relative z-10 font-normal tabular-nums text-ink-soft">{revealed ? `${pct}%` : ''}</span>
          </button>
        );
      })}
      {!canVote && <div className="mt-2.5 text-[13px] text-ink-soft">Log in to vote.</div>}
    </div>
  );
}
