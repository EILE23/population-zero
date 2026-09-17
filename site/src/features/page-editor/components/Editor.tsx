'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import { ImagePlus, Save } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { STARTERS } from '../starters';

interface Initial { shape: string; html: string; css: string; version: number }

/**
 * 집 에디터 — 왼쪽에 HTML·CSS, 오른쪽에 바로 보이는 미리보기.
 *
 * 미리보기는 sandbox iframe 이다. 여기서만은 그게 맞다 — 저장 전 글은 아직 씻기지 않았고,
 * 이 화면은 우리 앱 안이라 세션 쿠키가 살아 있다. 공개 페이지는 반대로 문서로 서빙하고 CSP 로 잠근다.
 */
export function Editor({ initial, href, canSave }: { initial: Initial | null; href: string; canSave: boolean }) {
  const [html, setHtml] = useState(initial?.html ?? '');
  const [css, setCss] = useState(initial?.css ?? '');
  const [shape, setShape] = useState(initial?.shape ?? '');
  const [note, setNote] = useState('');
  const [state, setState] = useState<'idle' | 'saving' | 'saved' | 'fail'>('idle');
  const [message, setMessage] = useState('');
  const [dropped, setDropped] = useState<string[]>([]);
  const [images, setImages] = useState<{ url: string }[] | null>(null);
  const [showImages, setShowImages] = useState(false);
  const htmlRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // 미리보기는 타이핑마다 다시 그리면 눈이 아프다 — 잠깐 멈출 때만 갱신한다
  const [debounced, setDebounced] = useState({ html, css });
  useEffect(() => {
    const t = setTimeout(() => setDebounced({ html, css }), 350);
    return () => clearTimeout(t);
  }, [html, css]);

  const preview = useMemo(() => `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>.poz-posts{list-style:none;padding:0;margin:0}.poz-posts li{padding:.3em 0}.poz-posts a{color:inherit}
.poz-note{padding:.5em 0;border-bottom:1px dotted currentColor}.poz-notes{list-style:none;padding:0;margin:0}
.poz-sign{display:flex;gap:.4em;margin-top:.6em}.poz-sign textarea{flex:1;font:inherit}</style>
<style>${debounced.css}</style></head><body>${debounced.html
    .replace(/<poz-posts[^>]*>(?:<\/poz-posts>)?/g, '<ul class="poz-posts"><li><a href="#">내가 쓴 글 제목</a></li><li><a href="#">그 전에 쓴 것</a></li></ul>')
    .replace(/<poz-guestbook[^>]*>(?:<\/poz-guestbook>)?/g, '<div class="poz-guestbook"><ul class="poz-notes"><li class="poz-note"><b>어떤_주민</b><p>여기 구석이 좋네요.</p></li></ul><form class="poz-sign"><textarea rows="2" placeholder="leave a note"></textarea><button type="button">sign</button></form></div>')
  }</body></html>`, [debounced]);

  function insert(text: string) {
    const el = htmlRef.current;
    if (!el) { setHtml(html + text); return; }
    const at = el.selectionStart ?? html.length;
    setHtml(html.slice(0, at) + text + html.slice(el.selectionEnd ?? at));
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
    if (!d.url) { setMessage(d.error ?? '올리지 못했습니다.'); return; }
    setImages([{ url: d.url }, ...(images ?? [])]);
    insert(`<img src="${d.url}" alt="">\n`);
  }

  async function save() {
    setState('saving'); setMessage(''); setDropped([]);
    const res = await fetch('/api/pages', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ html, css, shape, note }),
    });
    const d = await res.json() as { ok?: boolean; message?: string; dropped?: string[]; version?: number };
    if (!res.ok || !d.ok) { setState('fail'); setMessage(d.message ?? '저장하지 못했습니다.'); return; }
    setState('saved'); setNote(''); setDropped(d.dropped ?? []);
  }

  const pane = 'w-full rounded-lg border border-hairline bg-paper p-3 font-mono text-[12.5px] leading-relaxed outline-none focus:border-ink';

  return (
    <div className="mt-6">
      {!initial && (
        <div className="mb-6 rounded-2xl border border-hairline bg-paper p-5">
          <p className="text-[14.5px] font-semibold">어디서 시작할까요</p>
          <p className="mt-1 text-[13px] text-ink-soft">완성된 디자인이 아니라 &quot;이런 것도 페이지다&quot;의 예시입니다. 가져다 뜯어 고치세요.</p>
          <div className="mt-3 grid gap-2 sm:grid-cols-2">
            {STARTERS.map((s) => (
              <button
                key={s.key}
                onClick={() => { setHtml(s.html); setCss(s.css); setShape(s.shape); setNote(`${s.label}로 시작`); }}
                className="cursor-pointer rounded-lg border border-hairline bg-surface p-3 text-left hover:border-ink"
              >
                <span className="block text-[13.5px] font-bold">{s.label}</span>
                <span className="mt-0.5 block text-[12px] text-ink-soft">{s.hint}</span>
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="grid gap-5 lg:grid-cols-2">
        <div className="flex min-w-0 flex-col gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <button onClick={() => void openImages()} className={`${BUTTON.ghost} inline-flex items-center gap-1.5`}>
              <ImagePlus size={14} aria-hidden /> 그림
            </button>
            <button onClick={() => insert('<poz-posts limit="5"></poz-posts>\n')} className={BUTTON.ghost}>내 글 목록</button>
            <button onClick={() => insert('<poz-guestbook></poz-guestbook>\n')} className={BUTTON.ghost}>방명록</button>
          </div>

          {showImages && (
            <div className="rounded-lg border border-hairline bg-paper p-3">
              <div className="flex items-center justify-between">
                <p className="text-[13px] font-semibold">내 그림</p>
                <button onClick={() => setShowImages(false)} className="text-[12px] text-ink-soft hover:text-ink">닫기</button>
              </div>
              <input
                ref={fileRef} type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="mt-2 block w-full text-[12px]"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) void upload(f); e.target.value = ''; }}
              />
              {images === null ? <p className="mt-2 text-[12px] text-ink-soft">불러오는 중…</p> : images.length === 0 ? (
                <p className="mt-2 text-[12px] text-ink-soft">아직 올린 그림이 없습니다.</p>
              ) : (
                <div className="mt-2 grid max-h-52 grid-cols-4 gap-2 overflow-y-auto">
                  {images.map((im) => (
                    <button key={im.url} onClick={() => insert(`<img src="${im.url}" alt="">\n`)} className="cursor-pointer overflow-hidden rounded border border-hairline hover:border-ink">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={im.url} alt="" className="aspect-square w-full object-cover" />
                    </button>
                  ))}
                </div>
              )}
              <p className="mt-2 text-[11.5px] text-ink-soft">배경으로 깔려면 CSS 에 <code>background:url(주소)</code></p>
            </div>
          )}

          <label className="block">
            <span className="mb-1 block font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">HTML</span>
            <textarea ref={htmlRef} value={html} onChange={(e) => setHtml(e.target.value)} rows={16} spellCheck={false} className={pane} />
          </label>
          <label className="block">
            <span className="mb-1 block font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">CSS</span>
            <textarea value={css} onChange={(e) => setCss(e.target.value)} rows={12} spellCheck={false} className={pane} />
          </label>
        </div>

        <div className="min-w-0">
          <span className="mb-1 block font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">미리보기</span>
          <iframe
            sandbox=""
            title="미리보기"
            srcDoc={preview}
            className="h-150 w-full rounded-lg border border-hairline bg-white lg:sticky lg:top-4"
          />
        </div>
      </div>

      <div className="mt-6 rounded-2xl border border-hairline bg-paper p-5">
        <label className="block">
          <span className="text-[13.5px] font-semibold">이 페이지는 근본적으로 무엇인가</span>
          <span className="mt-0.5 block text-[12px] text-ink-soft">한 줄. 남의 집과 닮지 않게 잡아주는 말뚝입니다. 예: &quot;계속 늘어나는 장부 한 장&quot;</span>
          <input value={shape} onChange={(e) => setShape(e.target.value)} maxLength={120}
            className="mt-2 w-full rounded-lg border border-hairline bg-surface px-3 py-2 text-[14px] outline-none focus:border-ink" />
        </label>
        <label className="mt-4 block">
          <span className="text-[13.5px] font-semibold">오늘 뭘 했나</span>
          <span className="mt-0.5 block text-[12px] text-ink-soft">손댄 기록에 남습니다. 예: &quot;구석에 커피 자국 하나 넣었다&quot;</span>
          <input value={note} onChange={(e) => setNote(e.target.value)} maxLength={200}
            className="mt-2 w-full rounded-lg border border-hairline bg-surface px-3 py-2 text-[14px] outline-none focus:border-ink" />
        </label>
        <div className="mt-4 flex flex-wrap items-center gap-3">
          <button onClick={() => void save()} disabled={!canSave || state === 'saving' || !html.trim()}
            className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
            <Save size={14} aria-hidden /> {state === 'saving' ? '저장 중…' : '저장'}
          </button>
          {state === 'saved' && (
            <span className="text-[13px] font-semibold">
              저장했습니다 · <a className="underline" href={href}>내 집 보기 ↗</a>
            </span>
          )}
          {message && <span role="alert" className="text-[13px] font-semibold text-accent-deep">{message}</span>}
        </div>
        {dropped.length > 0 && (
          <p className="mt-3 text-[12.5px] text-ink-mid">
            저장할 때 빠진 것: <span className="font-mono">{dropped.join(', ')}</span>
            <span className="text-ink-soft"> — 스크립트와 외부 이미지는 받지 않습니다.</span>
          </p>
        )}
      </div>
    </div>
  );
}
