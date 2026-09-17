'use client';
import { useState } from 'react';
import { X } from 'lucide-react';
import { SubmitButton } from '@/components/SubmitButton';

interface AlertRow { id: number; keyword: string; region: string; created_at: string }

const REGIONS: [string, string][] = [
  ['', 'Every country'], ['KR', 'Korea'], ['US', 'United States'], ['GB', 'United Kingdom'], ['JP', 'Japan'],
  ['IN', 'India'], ['BR', 'Brazil'], ['DE', 'Germany'], ['FR', 'France'], ['MX', 'Mexico'], ['AU', 'Australia'],
  ['ID', 'Indonesia'], ['NG', 'Nigeria'],
];
const label = (r: string) => REGIONS.find(([v]) => v === r)?.[1] ?? 'Every country';

/** 키워드 목록과 아침 브리핑 설정 — 누르는 즉시 저장한다. */
export function AlertsManager({ initial, brief, briefRegion }: {
  initial: AlertRow[]; brief: boolean; briefRegion: string;
}) {
  const [alerts, setAlerts] = useState(initial);
  const [keyword, setKeyword] = useState('');
  const [region, setRegion] = useState('');
  const [error, setError] = useState('');
  const [briefOn, setBriefOn] = useState(brief);
  const [briefIn, setBriefIn] = useState(briefRegion);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    const kw = keyword.trim();
    if (kw.length < 2) return;
    setError('');
    const res = await fetch('/api/alerts', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ keyword: kw, region }),
    });
    if (!res.ok) { const d = await res.json().catch(() => ({})); setError((d as { message?: string }).message ?? 'Could not save that.'); return; }
    const list = await (await fetch('/api/alerts', { cache: 'no-store' })).json() as { alerts: AlertRow[] };
    setAlerts(list.alerts); setKeyword('');
  }

  async function remove(id: number) {
    setAlerts(alerts.filter((a) => a.id !== id));
    await fetch('/api/alerts', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ remove: id }) });
  }

  async function saveBrief(on: boolean, r: string) {
    setBriefOn(on); setBriefIn(r);
    await fetch('/api/me/brief', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ on, region: r }) });
  }

  return (
    <>
      <div className="rounded-2xl bg-paper p-5 shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
        <form onSubmit={add} className="flex flex-wrap items-center gap-2">
          <input
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            maxLength={60}
            placeholder="a word to watch, e.g. nvidia earnings"
            className="min-w-56 flex-1 rounded-lg border border-hairline bg-surface px-3 py-2.5 text-[15px] outline-none focus:border-ink"
          />
          <select
            value={region}
            onChange={(e) => setRegion(e.target.value)}
            className="rounded-lg border border-hairline bg-surface px-3 py-2.5 text-[14px] outline-none focus:border-ink"
          >
            {REGIONS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
          <SubmitButton variant="primary" pendingLabel="Adding…" disabled={keyword.trim().length < 2}>Watch it</SubmitButton>
        </form>
        {error && <p role="alert" className="mt-2 text-[13px] font-semibold text-accent-deep">{error}</p>}

        {alerts.length > 0 ? (
          <ul className="mt-4 flex flex-wrap gap-2">
            {alerts.map((a) => (
              <li key={a.id} className="inline-flex items-center gap-2 rounded-full border border-hairline bg-surface py-1.5 pl-3.5 pr-2 text-[13.5px]">
                <span className="font-semibold">{a.keyword}</span>
                <span className="text-[11.5px] text-ink-soft">{label(a.region)}</span>
                <button onClick={() => void remove(a.id)} aria-label={`Stop watching ${a.keyword}`} className="rounded-full p-1 text-ink-soft hover:bg-surface-deep hover:text-ink">
                  <X size={13} />
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-4 text-[13px] text-ink-soft">Nothing watched yet. A company, a game, a policy, your own name.</p>
        )}
      </div>

      <div className="mt-4 rounded-2xl bg-paper p-5 shadow-[0_1px_4px_rgba(0,0,0,0.05)]">
        <label className="flex cursor-pointer items-start gap-3">
          <input type="checkbox" checked={briefOn} onChange={(e) => void saveBrief(e.target.checked, briefIn)} className="mt-1 size-4 accent-accent" />
          <span>
            <span className="block text-[14.5px] font-semibold">The morning brief</span>
            <span className="block text-[12.5px] text-ink-soft">One email a day: what the press in your country ran overnight, and the one thread here worth reading.</span>
          </span>
        </label>
        {briefOn && (
          <div className="mt-3 flex items-center gap-2 pl-7 text-[13px]">
            <span className="text-ink-soft">Country</span>
            <select
              value={briefIn}
              onChange={(e) => void saveBrief(true, e.target.value)}
              className="rounded-lg border border-hairline bg-surface px-3 py-1.5 text-[13.5px] outline-none focus:border-ink"
            >
              <option value="">English, worldwide</option>
              {REGIONS.filter(([v]) => v).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </select>
          </div>
        )}
      </div>
    </>
  );
}
