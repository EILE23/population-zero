'use client';
import { useState } from 'react';
import { ArrowLeftRight, GripVertical, ImagePlus, Plus, Save, Settings2, Trash2, X } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { BlogCanvas } from '@/features/blog/components/BlogCanvas';
import { cleanLayout, DEFAULT_LAYOUT, type Block, type BlockKind, type BlogLayout, type Theme } from '@/lib/blog-layout';
import type { ProfileData } from '@/features/blog/types';
import { BlockSettings, KIND_LABEL, ONCE, Row } from './BlockSettings';

type CanvasData = Pick<ProfileData, 'owner' | 'posts' | 'topics' | 'pinnedPost' | 'seriesList' | 'followerCount' | 'followingCount' | 'isMe'>;

/**
 * 블로그 편집기 — 옆 목록이 아니라 **화면에서 직접** 만진다.
 *
 * 블로그 실물(BlogCanvas)을 그대로 띄우고 그 위에 손잡이를 덧입힌다. 섹션을 잡아 그 자리에서 끌어 옮기고,
 * 블록 사이의 + 를 눌러 새 블록을 그 자리에 넣고, 블록을 고르면 바로 아래에서 설정이 열린다.
 * 위쪽 띠에는 블로그 전체에 걸리는 것(기둥·폭·색·서체)만 둔다.
 *
 * 저장되는 건 코드가 아니라 고른 값이다 — 주민도 같은 값을 쓴다(사람은 마우스, 주민은 JSON).
 */
const SWATCHES: [string, string, string][] = [
  ['#f7f5f6', '#1B0C15', '#AD7096'],
  ['#f4efe6', '#191512', '#9a3b2f'],
  ['#ffffff', '#111111', '#2563eb'],
  ['#0e0d12', '#d7d2de', '#8f7bd4'],
  ['#0d0f0c', '#d8e0cf', '#7bb661'],
  ['#fffdf8', '#151515', '#ff5a2b'],
];

export function EditorShell({ initial, data, base, canSave }: {
  initial: BlogLayout; data: CanvasData; base: string; canSave: boolean;
}) {
  const [layout, setLayout] = useState<BlogLayout>(initial);
  const [picked, setPicked] = useState<string | null>(null);
  const [drag, setDrag] = useState<string | null>(null);
  const [insertAt, setInsertAt] = useState<number | null>(null);
  const [picking, setPicking] = useState<string | null>(null);
  const [images, setImages] = useState<{ url: string }[] | null>(null);
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [message, setMessage] = useState('');
  const [note, setNote] = useState('');

  const set = (patch: Partial<BlogLayout>) => setLayout(cleanLayout({ ...layout, ...patch }));
  const setTheme = (patch: Partial<Theme>) => set({ theme: { ...layout.theme, ...patch } });
  const setProp = (id: string, key: string, v: string | number | boolean) =>
    set({ blocks: layout.blocks.map((b) => (b.id === id ? { ...b, props: { ...(b.props ?? {}), [key]: v } } : b)) });

  /** 끌어 옮기기 — 지나가는 블록과 자리를 바꾼다(놓을 때가 아니라 지나갈 때 움직여서 결과가 바로 보인다) */
  const dropOn = (targetId: string) => {
    if (!drag || drag === targetId) return;
    const from = layout.blocks.findIndex((b) => b.id === drag);
    const to = layout.blocks.findIndex((b) => b.id === targetId);
    if (from < 0 || to < 0) return;
    const next = layout.blocks.slice();
    next.splice(to, 0, ...next.splice(from, 1));
    set({ blocks: next });
  };

  const insert = (kind: BlockKind, at: number) => {
    const id = `${kind}-${Math.random().toString(36).slice(2, 6)}`;
    const next = layout.blocks.slice();
    next.splice(at, 0, { id, kind });
    set({ blocks: next });
    setInsertAt(null);
    setPicked(id);
  };

  async function loadImages() {
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
    applyImage(d.url);
  }

  function applyImage(url: string) {
    if (!picking) return;
    const b = layout.blocks.find((x) => x.id === picking);
    if (!b) return;
    if (b.kind === 'header') { setProp(b.id, 'image', url); setProp(b.id, 'fill', 'image'); }
    else setProp(b.id, b.kind === 'banner' ? 'image' : 'src', url);
    setPicking(null);
  }

  async function save() {
    if (!canSave) { setMessage('Verify your email first — your blog is public.'); return; }
    setSaving(true); setMessage('');
    const res = await fetch('/api/pages', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ layout, note, shape: describe(layout) }),
    });
    const d = await res.json() as { ok?: boolean; message?: string };
    setSaving(false);
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not save that.'); return; }
    setSavedAt(new Date().toLocaleTimeString()); setNote('');
  }

  const chip = (on: boolean) =>
    `cursor-pointer rounded-full px-2.5 py-1 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'border border-hairline bg-paper text-ink-mid hover:bg-surface'}`;

  const canAdd = (Object.keys(KIND_LABEL) as BlockKind[])
    .filter((k) => !(ONCE.includes(k) && layout.blocks.some((b) => b.kind === k)));

  /** 블록 하나를 감싸는 편집 껍데기 — 손잡이, 단추, 그리고 고른 블록의 설정 */
  const wrapBlock = (block: Block, node: React.ReactNode, index: number) => {
    const on = picked === block.id;
    return (
      <>
        <InsertRow
          open={insertAt === index}
          onOpen={() => setInsertAt(insertAt === index ? null : index)}
          kinds={canAdd}
          onPick={(k) => insert(k, index)}
        />
        <div
          draggable
          onDragStart={(e) => { setDrag(block.id); e.dataTransfer.effectAllowed = 'move'; }}
          onDragOver={(e) => { e.preventDefault(); dropOn(block.id); }}
          onDragEnd={() => setDrag(null)}
          onClick={(e) => { e.stopPropagation(); setPicked(on ? null : block.id); }}
          className={`group relative cursor-grab rounded-md outline-offset-2 transition-[outline-color] ${
            on ? 'outline outline-2 outline-accent' : 'outline outline-1 outline-transparent hover:outline-hairline'
          } ${drag === block.id ? 'opacity-50' : ''}`}
        >
          <div className={`absolute -top-3 left-1.5 z-10 flex items-center gap-0.5 rounded-full border border-hairline bg-paper px-1.5 py-0.5 shadow-sm transition-opacity ${on ? '' : 'opacity-0 group-hover:opacity-100'}`}>
            <GripVertical size={12} aria-hidden className="text-ink-soft" />
            <span className="mr-1 text-[10.5px] font-bold">{KIND_LABEL[block.kind]}</span>
            {layout.shell !== 'stack' && (
              <IconBtn label="Move to the side column" onClick={() => set({ blocks: layout.blocks.map((b) => (b.id === block.id ? { ...b, rail: !b.rail } : b)) })}>
                <ArrowLeftRight size={11} className={block.rail ? 'text-accent-deep' : ''} />
              </IconBtn>
            )}
            <IconBtn label="Settings" onClick={() => setPicked(on ? null : block.id)}><Settings2 size={11} /></IconBtn>
            {block.kind !== 'posts' && (
              <IconBtn label="Remove" onClick={() => { set({ blocks: layout.blocks.filter((b) => b.id !== block.id) }); setPicked(null); }}>
                <Trash2 size={11} />
              </IconBtn>
            )}
          </div>

          <div className="pointer-events-none">{node}</div>
        </div>

        {on && (
          <div className="mt-2 flex flex-col gap-2.5 rounded-xl border border-accent/40 bg-surface p-3" onClick={(e) => e.stopPropagation()}>
            <BlockSettings
              block={block}
              setProp={(k, v) => setProp(block.id, k, v)}
              onPickImage={() => { setPicking(block.id); void loadImages(); }}
            />
          </div>
        )}

        {index === layout.blocks.length - 1 && (
          <InsertRow
            open={insertAt === layout.blocks.length}
            onOpen={() => setInsertAt(insertAt === layout.blocks.length ? null : layout.blocks.length)}
            kinds={canAdd}
            onPick={(k) => insert(k, layout.blocks.length)}
          />
        )}
      </>
    );
  };

  return (
    <div className="mt-5" onClick={() => setPicked(null)}>
      {/* ── 블로그 전체에 걸리는 것 ── */}
      <div className="sticky top-0 z-20 -mx-1 flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-hairline bg-paper/95 px-3 py-2.5 backdrop-blur">
        <div className="flex items-center gap-1.5">
          {([['stack', 'One column'], ['rail-left', 'Side left'], ['rail-right', 'Side right']] as const).map(([v, l]) => (
            <button key={v} onClick={() => set({ shell: v })} className={chip(layout.shell === v)}>{l}</button>
          ))}
        </div>
        <div className="flex items-center gap-1.5">
          {([['narrow', 'Narrow'], ['normal', 'Normal'], ['wide', 'Wide']] as const).map(([v, l]) => (
            <button key={v} onClick={() => set({ width: v })} className={chip(layout.width === v)}>{l}</button>
          ))}
        </div>
        <div className="flex items-center gap-1.5">
          {SWATCHES.map(([bg, ink, accent]) => (
            <button
              key={bg + ink} onClick={() => setTheme({ bg, ink, accent })} aria-label={`palette ${bg}`}
              className={`size-6 cursor-pointer rounded-full border-2 ${layout.theme.bg === bg && layout.theme.ink === ink ? 'border-ink' : 'border-hairline'}`}
              style={{ background: `linear-gradient(135deg, ${bg} 0 50%, ${ink} 50% 80%, ${accent} 80% 100%)` }}
            />
          ))}
          {([['bg', 'Page'], ['ink', 'Text'], ['accent', 'Accent']] as const).map(([k, label]) => (
            <input
              key={k} type="color" aria-label={label} value={layout.theme[k]}
              onChange={(e) => setTheme({ [k]: e.target.value } as Partial<Theme>)}
              className="size-6 cursor-pointer rounded border border-hairline bg-transparent p-0"
            />
          ))}
        </div>
        <details className="relative">
          <summary className={`${chip(false)} list-none`}>More</summary>
          <div className="absolute right-0 top-8 z-30 flex w-64 flex-col gap-2.5 rounded-xl border border-hairline bg-paper p-3 shadow-lg">
            <Row label="Font">
              {([['sans', 'Sans'], ['serif', 'Serif'], ['mono', 'Mono']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ font: v })} className={chip(layout.theme.font === v)}>{l}</button>
              ))}
            </Row>
            <Row label="Corners">
              {([['none', 'Sharp'], ['sm', 'Soft'], ['lg', 'Round'], ['pill', 'Pill']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ radius: v })} className={chip(layout.theme.radius === v)}>{l}</button>
              ))}
            </Row>
            <Row label="Spacing">
              {([['tight', 'Tight'], ['normal', 'Normal'], ['roomy', 'Roomy']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ density: v })} className={chip(layout.theme.density === v)}>{l}</button>
              ))}
            </Row>
            <Row label="Lines">
              {([['none', 'None'], ['hairline', 'Thin'], ['bold', 'Thick']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ border: v })} className={chip(layout.theme.border === v)}>{l}</button>
              ))}
            </Row>
            <button onClick={() => set(DEFAULT_LAYOUT)} className={`${chip(false)} mt-1`}>Start over</button>
          </div>
        </details>

        <div className="ml-auto flex items-center gap-2">
          <input
            value={note} onChange={(e) => setNote(e.target.value)} maxLength={200}
            placeholder="What you changed (optional)"
            className="w-44 rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[12.5px] outline-none focus:border-ink"
          />
          <button onClick={() => void save()} disabled={saving} className={`${BUTTON.primary} inline-flex items-center gap-1.5 !py-1.5 disabled:opacity-50`}>
            <Save size={13} aria-hidden /> {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>

      {message && <p role="alert" className="mt-2 text-[13px] font-semibold text-accent-deep">{message}</p>}
      {savedAt && !message && <p className="mt-2 text-[12.5px] text-ink-soft">Saved {savedAt} · <a className="underline" href={base}>open your blog ↗</a></p>}

      {/* ── 화면 자체가 편집면 ── */}
      <div className="mt-4 overflow-hidden rounded-xl border border-hairline">
        <div className="p-4 sm:p-7">
          <BlogCanvas layout={layout} data={data} base={base} viewer editing blockWrap={wrapBlock} />
        </div>
      </div>

      {picking && (
        <div className="fixed inset-x-4 bottom-4 z-40 mx-auto max-w-lg rounded-xl border border-hairline bg-paper p-4 shadow-xl">
          <div className="flex items-center justify-between">
            <p className="text-[13px] font-bold">Pick a picture</p>
            <button onClick={() => setPicking(null)} aria-label="Close" className="cursor-pointer text-ink-soft hover:text-ink"><X size={14} /></button>
          </div>
          <label className={`${BUTTON.ghost} mt-2 inline-flex cursor-pointer items-center gap-1.5`}>
            <ImagePlus size={13} aria-hidden /> Upload
            <input type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void upload(f); }} />
          </label>
          {images?.length ? (
            <div className="mt-2 grid max-h-40 grid-cols-5 gap-2 overflow-y-auto">
              {images.map((im) => (
                <button key={im.url} onClick={() => applyImage(im.url)} className="cursor-pointer overflow-hidden rounded border border-hairline hover:border-ink">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={im.url} alt="" className="aspect-square w-full object-cover" />
                </button>
              ))}
            </div>
          ) : <p className="mt-2 text-[12px] text-ink-soft">Nothing uploaded yet.</p>}
        </div>
      )}
    </div>
  );
}

function IconBtn({ label, onClick, children }: { label: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      aria-label={label} title={label}
      onClick={(e) => { e.stopPropagation(); onClick(); }}
      className="cursor-pointer rounded p-1 text-ink-soft hover:bg-surface hover:text-ink"
    >
      {children}
    </button>
  );
}

/** 블록 사이의 + — 새 블록이 정확히 그 자리에 들어간다 */
function InsertRow({ open, onOpen, kinds, onPick }: {
  open: boolean; onOpen: () => void; kinds: BlockKind[]; onPick: (k: BlockKind) => void;
}) {
  return (
    <div className="group/ins relative flex h-5 items-center justify-center" onClick={(e) => e.stopPropagation()}>
      <button
        onClick={onOpen} aria-label="Add a block here"
        className={`inline-flex size-5 items-center justify-center rounded-full border border-hairline bg-paper text-ink-soft transition-opacity hover:border-ink hover:text-ink ${open ? '' : 'opacity-0 group-hover/ins:opacity-100'}`}
      >
        <Plus size={11} />
      </button>
      {open && (
        <div className="absolute top-6 z-30 flex flex-wrap justify-center gap-1.5 rounded-xl border border-hairline bg-paper p-2 shadow-lg">
          {kinds.map((k) => (
            <button key={k} onClick={() => onPick(k)}
              className="cursor-pointer rounded-full border border-hairline px-2.5 py-1 text-[12px] font-bold text-ink-mid hover:bg-surface">
              {KIND_LABEL[k]}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** 블로그 목록에 뜨는 한 줄 — 고른 값에서 자동으로 만든다(사람이 또 쓸 일은 없다) */
function describe(l: BlogLayout): string {
  const posts = l.blocks.find((b) => b.kind === 'posts')?.props?.view ?? 'grid';
  const shell = l.shell === 'stack' ? 'one column' : l.shell === 'rail-left' ? 'a left side column' : 'a right side column';
  const view = { grid: 'cards', magazine: 'a magazine front', list: 'a list', index: 'titles only' }[String(posts)] ?? 'cards';
  const dark = isDark(l.theme.bg);
  return `${shell}, ${view}${dark ? ', dark' : ''}`;
}

function isDark(hex: string): boolean {
  const h = hex.replace('#', '');
  const v = h.length === 3 ? h.split('').map((c) => c + c).join('') : h.slice(0, 6);
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(v.slice(i, i + 2), 16) || 0);
  return (r * 0.299 + g * 0.587 + b * 0.114) < 128;
}
