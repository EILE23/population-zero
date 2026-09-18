'use client';
import { Bell, MessageCircle, Search } from 'lucide-react';
import { CHROME_ITEMS, type Chrome, type ChromeItem } from '@/lib/blog-layout';
import { BrandLogo } from '@/components/BrandLogo';

const LABEL: Record<ChromeItem, string> = {
  search: 'Search', about: 'About', contact: 'Contact', bell: 'Bell',
  messages: 'Messages', write: 'Write', account: 'My account',
};

/**
 * 편집기 안에서 만지는 사이트 띠 — 검색창·About·Contact·알림·쪽지·Write·계정.
 *
 * 이건 우리 것이지만 이 블로그에서 어떻게 보일지는 주인이 정한다. 그래서 미리보기 안에 넣었다:
 * 설정이 More 서랍 안에만 있으면 "헤더는 못 고치는 것"과 같다 — 화면에서 보이고 눌려야 고칠 수 있다.
 *
 * NavActions(서버)를 그대로 쓸 수 없어 같은 항목·같은 순서로 그린 정적 판이다.
 * 항목 목록은 한 곳(chrome.items)에서 오므로 목록이 갈라질 일은 없다.
 */
export function SiteBarPreview({ chrome, handle }: { chrome: Chrome; handle: string }) {
  const piece = (k: ChromeItem) => {
    switch (k) {
      case 'search':
        return (
          <span key={k} className="inline-flex items-center gap-1 border-b border-current/30 pb-0.5 text-[13px] opacity-70">
            <Search size={13} aria-hidden /> Search
          </span>
        );
      case 'about': return <span key={k} className="text-[13px] font-semibold">About</span>;
      case 'contact': return <span key={k} className="text-[13px] font-semibold">Contact</span>;
      case 'bell': return <Bell key={k} size={17} aria-hidden />;
      case 'messages': return <MessageCircle key={k} size={17} aria-hidden />;
      case 'write':
        return (
          <span key={k} className="rounded-full border border-current px-3 py-1 text-[12.5px] font-bold">Write</span>
        );
      case 'account':
        return (
          <span key={k} className="inline-flex items-center gap-1.5 text-[13px] font-semibold">
            <span aria-hidden className="inline-block size-4 rounded-full bg-current opacity-30" />
            {handle}
          </span>
        );
      default: return null;
    }
  };

  const keys = chrome.items.filter((k) => k !== 'account');
  return (
    <div data-pz="sitebar" className="flex flex-wrap items-center gap-x-4 gap-y-2">
      {chrome.home !== 'none' && (
        <span className="mr-auto inline-flex items-center gap-1.5 font-mono text-[10.5px] font-bold uppercase tracking-[0.16em] opacity-70">
          <span aria-hidden>←</span>
          {chrome.home === 'label' ? (chrome.label || 'POZ') : <BrandLogo className="w-10" />}
        </span>
      )}
      {keys.map(piece)}
      {piece('account')}
    </div>
  );
}

/** 사이트 띠 설정 — 자리, 무엇을 둘지, 어떤 순서로 */
export function SiteBarSettings({ chrome, onChange }: { chrome: Chrome; onChange: (next: Chrome) => void }) {
  const chip = (on: boolean) =>
    `cursor-pointer rounded-full px-2.5 py-1 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'border border-hairline bg-paper text-ink-mid hover:bg-surface'}`;
  const row = 'mb-1 font-mono text-[10px] uppercase tracking-[0.12em] text-ink-soft';

  const toggle = (k: ChromeItem) => {
    const on = chrome.items.includes(k);
    const items = on
      ? chrome.items.filter((x) => x !== k)
      : [...chrome.items.filter((x) => x !== 'account'), k, 'account' as ChromeItem];
    onChange({ ...chrome, items });
  };
  const move = (k: ChromeItem, dir: -1 | 1) => {
    const list: ChromeItem[] = chrome.items.filter((x) => x !== 'account');
    const i = list.indexOf(k);
    const j = i + dir;
    if (i < 0 || j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    onChange({ ...chrome, items: [...list, 'account' as ChromeItem] });
  };

  return (
    <div className="flex flex-col gap-2.5">
      <div>
        <p className={row}>Where it sits</p>
        <div className="flex flex-wrap gap-1.5">
          {([['top', 'Top'], ['bottom', 'Bottom'], ['off', 'Off']] as const).map(([v, l]) => (
            <button key={v} onClick={() => onChange({ ...chrome, nav: v })} className={chip(chrome.nav === v)}>{l}</button>
          ))}
        </div>
        {chrome.nav === 'off' && (
          <p className="mt-1 text-[11.5px] text-ink-soft">
            Off means you add a <b>Header bar</b> block and put it where you like.
          </p>
        )}
      </div>

      <div>
        <p className={row}>Home link</p>
        <div className="flex flex-wrap gap-1.5">
          {([['logo', 'POZ logo'], ['label', 'My words'], ['none', 'Hide']] as const).map(([v, l]) => (
            <button key={v} onClick={() => onChange({ ...chrome, home: v })} className={chip(chrome.home === v)}>{l}</button>
          ))}
        </div>
        {chrome.home === 'label' && (
          <input
            value={chrome.label}
            onChange={(e) => onChange({ ...chrome, label: e.target.value })}
            maxLength={24}
            placeholder="back"
            className="mt-1.5 w-full rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[13px] outline-none focus:border-ink"
          />
        )}
      </div>

      <div>
        <p className={row}>What&apos;s in it, in order</p>
        <ul className="flex flex-col gap-1">
          {CHROME_ITEMS.filter((k) => k !== 'account').map((k) => {
            const on = chrome.items.includes(k);
            return (
              <li key={k} className="flex items-center gap-1.5">
                <button onClick={() => toggle(k)} className={`${chip(on)} flex-1 text-left`}>{LABEL[k]}</button>
                <button onClick={() => move(k, -1)} disabled={!on} aria-label={`Move ${LABEL[k]} left`}
                  className="cursor-pointer rounded px-1 text-ink-soft hover:text-ink disabled:opacity-30">←</button>
                <button onClick={() => move(k, 1)} disabled={!on} aria-label={`Move ${LABEL[k]} right`}
                  className="cursor-pointer rounded px-1 text-ink-soft hover:text-ink disabled:opacity-30">→</button>
              </li>
            );
          })}
        </ul>
        <p className="mt-1 text-[11.5px] text-ink-soft">
          My account stays — it is the only way out to log out and to your own page.
        </p>
      </div>
    </div>
  );
}
