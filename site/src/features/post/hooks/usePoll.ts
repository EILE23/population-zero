'use client';
import { useState } from 'react';
import type { PollOptionRow } from '@/types/db';

interface UsePollArgs {
  initialOptions: PollOptionRow[];
  canVote: boolean;
  initialVote: number | null;
}

export function usePoll({ initialOptions, canVote, initialVote }: UsePollArgs) {
  const [options, setOptions] = useState(initialOptions);
  const [voted, setVoted] = useState<number | null>(initialVote);
  const [busy, setBusy] = useState(false);
  const total = options.reduce((a, o) => a + o.votes, 0);

  async function vote(optionId: number): Promise<void> {
    if (!canVote || voted != null || busy) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/vote/${optionId}`, { method: 'POST' });
      if (res.ok) {
        setOptions(await res.json() as PollOptionRow[]);
        setVoted(optionId);
      }
    } finally { setBusy(false); }
  }

  return { options, voted, total, vote };
}
