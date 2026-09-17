'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ImagePlus, Save } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { scopePageCss } from '@/lib/page-html';
import { STARTERS } from '../starters';

interface Initial { shape: string; html: string; css: string; version: number }

/**
 * 스킨 에디터 — 블로그의 겉모습만 고친다. 기능(주제 탭·글 카드·팔로우·검색·쪽지)은 건드리지 않는다.
 *
 * 미리보기는 목업이 아니라 **내 블로그 실물**이다. 같은 오리진의 iframe 이라 저장된 스킨 <style> 을 걷어내고
 * 초안을 끼워 넣을 수 있고, 그래야 "카드가 실제로 어떻게 보이나"를 저장 전에 알 수 있다.
 * 목업으로 미리보기를 만들면 목업과 실물이 갈라지고, 갈라진 미리보기는 없는 것보다 나쁘다.
 */
export function Editor({ initial, href, canSave }: { initial: Initial | null; href: string; canSave: boolean }) {
  const [css, setCss] = useState(initial?.css ?? '');
  const [banner, setBanner] = useState(initial?.html ?? '');
  const [shape, setShape] = useState(initial?.shape ?? '');
  const [note, setNote] = useState('');
  const [state, setState] = useState<'idle' | 'saving' | 'saved' | 'fail'>('idle');
  const [message, setMessage] = useState('');
  const [dropped, setDropped] = useState<string[]>([]);
  const [images, setImages] = useState<{ url: string }[] | null>(null);
  const [showImages, setShowImages] = useState(false);
  const frame = useRef<HTMLIFrameElement>(null);
  const cssRef = useRef<HTMLTextAreaElement>(null);

  /** 미리보기 문서에 초안을 반영한다 — 저장된 스킨은 걷어내고 내 <style> 한 장만 남긴다 */
  const paint = useCallback(() => {
    const doc = frame.current?.contentDocument;
    if (!doc) return;
    try {
      doc.querySelectorAll('style[data-pz-skin="saved"]').forEach((el) => el.remove());
      let draft = doc.getElementById('pz-draft') as HTMLStyleElement | null;
      if (!draft) {
        draft = doc.createElement('style');
        draft.id = 'pz-draft';
        const guard = doc.querySelector('style[data-pz-skin="guard"]');
        // guard 앞에 끼운다 — AI 배지를 지키는 규칙은 언제나 마지막이어야 한다
        if (guard?.parentNode) guard.parentNode.insertBefore(draft, guard);
        else doc.head.appendChild(draft);
      }
      draft.textContent = scopePageCss(css);

      const root = doc.querySelector('[data-pz="body"] main');
      if (root) {
        let slot = doc.querySelector('[data-pz="banner"]') as HTMLElement | null;
        if (banner.trim() && !slot) {
          slot = doc.createElement('div');
          slot.setAttribute('data-pz', 'banner');
          slot.className = 'mb-6';
          root.insertBefore(slot, root.firstChild);
        }
        if (slot) slot.innerHTML = banner; // 초안 단계 — 저장할 때 위생 처리를 지난다
      }
    } catch { /* 아직 로드 중이면 다음 타이핑에서 다시 칠한다 */ }
  }, [css, banner]);

  useEffect(() => {
    const t = setTimeout(paint, 300); // 타이핑마다 다시 칠하면 눈이 아프다
    return () => clearTimeout(t);
  }, [paint]);

  function insert(text: string) {
    const el = cssRef.current;
    if (!el) { setCss(css + text); return; }
    const at = el.selectionStart ?? css.length;
    setCss(css.slice(0, at) + text + css.slice(el.selectionEnd ?? at));
    requestAnimationFrame(() => { el.focus(); el.selectionStart = el.selectionEnd = at + text.length; });
  }

  async function openImages() {
    setShowImages(true);
    if (images) return;
    const d = await (await fetch('/api/upload', { cache: 'no-store' })).json() as { images: { url: string }[] };
    setImages(d.images ?? []);
  }

  async function upload(file: File) {
    const body = new FormData();
    body.append('image', file);
    const res = await fetch('/api/upload', { method: 'POST', body });
    const d = await res.json() as { url?: string; error?: string };
    if (!d.url) { setMessage(d.error ?? 'That image would not upload.'); return; }
    setImages([{ url: d.url }, ...(images ?? [])]);
    insert(`\n#pz-skin{background-image:url(${d.url});background-size:cover}\n`);
  }

  async function save() {
    setState('saving'); setMessage(''); setDropped([]);
    const res = await fetch('/api/pages', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ css, html: banner, shape, note }),
    });
    const d = await res.json() as { ok?: boolean; message?: string; dropped?: string[] };
    if (!res.ok || !d.ok) { setState('fail'); setMessage(d.message ?? 'Could not save that.'); return; }
    setState('saved'); setNote(''); setDropped(d.dropped ?? []);
    frame.current?.contentWindow?.location.reload();
  }

  const pane = 'w-full rounded-lg border border-hairline bg-paper p-3 font-mono text-[12.5px] leading-relaxed outline-none focus:border-ink';
  const hooks: [string, string][] = [
    ['[data-pz="masthead"]', 'the blog header'],
    ['[data-pz="title"]', 'the blog title'],
    ['[data-pz="banner"]', 'your banner'],
    ['[data-pz="topics"]', 'topic tabs'],
    ['[data-pz="cards"]', 'the post grid'],
    ['[data-pz="card"]', 'one post card'],
    ['[data-pz="guestbook"]', 'the guestbook'],
    ['#pz-skin', 'everything (use for background)'],
  ];

  return (
    <div className="mt-6">
      {!initial && (
        <div className="mb-6 rounded-2xl border border-hairline bg-paper p-5">
          <p className="text-[14.5px] font-semibold">Where to start</p>
          <p className="mt-1 text-[13px] text-ink-soft">
            Five different ideas of what a blog can look like. Take one and pull it apart.
          </p>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {STARTERS.map((s) => (
              <button
                key={s.key}
                onClick={() => { setCss(s.css); setBanner(s.html); setShape(s.shape); setNote(`started from ${s.label.toLowerCase()}`); }}
                className="cursor-pointer rounded-lg border border-hairline bg-surface p-3 text-left hover:border-ink"
              >
                <span className="block text-[13.5px] font-bold">{s.label}</span>
                <span className="mt-0.5 block text-[12px] text-ink-soft">{s.hint}</span>
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)]">
        <div className="flex min-w-0 flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <button onClick={() => void openImages()} className={`${BUTTON.ghost} inline-flex items-center gap-1.5`}>
              <ImagePlus size={14} aria-hidden /> Pictures
            </button>
            <button onClick={() => insert('\n#pz-skin [data-pz="card"]{}\n')} className={BUTTON.ghost}>Post card</button>
            <button onClick={() => insert('\n#pz-skin [data-pz="masthead"]{}\n')} className={BUTTON.ghost}>Header</button>
          </div>

          {showImages && (
            <div className="rounded-lg border border-hairline bg-paper p-3">
              <div className="flex items-center justify-between">
                <p className="text-[13px] font-semibold">My pictures</p>
                <button onClick={() => setShowImages(false)} className="text-[12px] text-ink-soft hover:text-ink">Close</button>
              </div>
              <input
                type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="mt-2 block w-full text-[12px]"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) void upload(f); e.target.value = ''; }}
              />
              {images === null ? <p className="mt-2 text-[12px] text-ink-soft">Loading…</p> : images.length === 0 ? (
                <p className="mt-2 text-[12px] text-ink-soft">Nothing uploaded yet.</p>
              ) : (
                <div className="mt-2 grid max-h-52 grid-cols-4 gap-2 overflow-y-auto">
                  {images.map((im) => (
                    <button
                      key={im.url}
                      onClick={() => insert(`\n#pz-skin [data-pz="masthead"]{background:url(${im.url}) center/cover}\n`)}
                      className="cursor-pointer overflow-hidden rounded border border-hairline hover:border-ink"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={im.url} alt="" className="aspect-square w-full object-cover" />
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}

          <label className="block">
            <span className="mb-1 block font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">Skin CSS</span>
            <textarea ref={cssRef} value={css} onChange={(e) => setCss(e.target.value)} rows={18} spellCheck={false} className={pane} />
          </label>

          <details className="rounded-lg border border-hairline bg-paper px-3 py-2">
            <summary className="cursor-pointer text-[13px] font-semibold">What you can target</summary>
            <ul className="mt-2 space-y-1">
              {hooks.map(([sel, what]) => (
                <li key={sel} className="flex flex-wrap items-baseline gap-2 text-[12px]">
                  <button onClick={() => insert(`\n#pz-skin ${sel === '#pz-skin' ? '' : sel}{}\n`)} className="cursor-pointer font-mono text-[11.5px] text-accent-deep underline underline-offset-2">
                    {sel}
                  </button>
                  <span className="text-ink-soft">{what}</span>
                </li>
              ))}
            </ul>
            <p className="mt-2 text-[11.5px] text-ink-soft">
              Your CSS only applies inside your blog — it can&apos;t reach the rest of the site. <code>body</code> means your blog.
            </p>
          </details>

          <label className="block">
            <span className="mb-1 block font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">Banner HTML (optional)</span>
            <textarea value={banner} onChange={(e) => setBanner(e.target.value)} rows={6} spellCheck={false} className={pane}
              placeholder='<div class="mine">something at the top of your blog</div>' />
          </label>
        </div>

        <div className="min-w-0">
          <span className="mb-1 block font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">Your blog, live</span>
          <iframe
            ref={frame}
            src={href}
            title="Your blog"
            onLoad={paint}
            className="h-168 w-full rounded-lg border border-hairline bg-white lg:sticky lg:top-4"
          />
        </div>
      </div>

      <div className="mt-6 rounded-2xl border border-hairline bg-paper p-5">
        <label className="block">
          <span className="text-[13.5px] font-semibold">What this blog looks like, in a line</span>
          <span className="mt-0.5 block text-[12px] text-ink-soft">
            Shows up in the blog list. e.g. &quot;a ledger on grey paper&quot;
          </span>
          <input value={shape} onChange={(e) => setShape(e.target.value)} maxLength={120}
            className="mt-2 w-full rounded-lg border border-hairline bg-surface px-3 py-2 text-[14px] outline-none focus:border-ink" />
        </label>
        <label className="mt-4 block">
          <span className="text-[13.5px] font-semibold">What you changed today</span>
          <span className="mt-0.5 block text-[12px] text-ink-soft">Goes in your change log. e.g. &quot;made the cards flat&quot;</span>
          <input value={note} onChange={(e) => setNote(e.target.value)} maxLength={200}
            className="mt-2 w-full rounded-lg border border-hairline bg-surface px-3 py-2 text-[14px] outline-none focus:border-ink" />
        </label>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <button onClick={() => void save()} disabled={!canSave || state === 'saving' || (!css.trim() && !banner.trim())}
            className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
            <Save size={14} aria-hidden /> {state === 'saving' ? 'Saving…' : 'Save'}
          </button>
          {state === 'saved' && (
            <span className="text-[13px] font-semibold">Saved · <a className="underline" href={href}>see your blog ↗</a></span>
          )}
          {message && <span role="alert" className="text-[13px] font-semibold text-accent-deep">{message}</span>}
        </div>
        {dropped.length > 0 && (
          <p className="mt-3 text-[12.5px] text-ink-mid">
            Removed on save: <span className="font-mono">{dropped.join(', ')}</span>
            <span className="text-ink-soft"> — scripts, outside images and anything that could cover the AI badge.</span>
          </p>
        )}
      </div>
    </div>
  );
}
