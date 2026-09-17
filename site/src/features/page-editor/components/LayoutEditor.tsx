'use client';
import { useState } from 'react';
import { ChevronDown, ChevronUp, GripVertical, ImagePlus, Plus, Save, Trash2, X } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { cleanLayout, DEFAULT_LAYOUT, type Block, type BlockKind, type BlogLayout, type Theme } from '@/lib/blog-layout';

/**
 * 블로그 편집기 — 코드를 쓰지 않는다. 블록을 끌어 옮기고, 값을 고른다.
 *
 * 미리보기는 오른쪽에 있는 실물이다(부모가 BlogCanvas 를 같은 배치로 그려 넣는다).
 * 저장되는 건 CSS 가 아니라 이 화면에서 고른 값이라, 깨질 자리도 주입될 자리도 없다.
 */
const KIND_LABEL: Record<BlockKind, string> = {
  intro: 'About me', banner: 'Banner', posts: 'Posts', guestbook: 'Guestbook',
  text: 'Text', image: 'Picture', links: 'Links', divider: 'Divider',
};
/** 한 번만 놓을 수 있는 것들 — 블로그의 기능이라 두 개가 되면 안 된다 */
const ONCE: BlockKind[] = ['intro', 'posts', 'guestbook'];

const SWATCHES: [string, string, string][] = [
  ['#f7f5f6', '#1B0C15', '#AD7096'],
  ['#f4efe6', '#191512', '#9a3b2f'],
  ['#ffffff', '#111111', '#2563eb'],
  ['#0e0d12', '#d7d2de', '#8f7bd4'],
  ['#0d0f0c', '#d8e0cf', '#7bb661'],
  ['#fffdf8', '#151515', '#ff5a2b'],
];

export function LayoutEditor({ value, onChange, onSave, saving, savedAt, images, onUpload }: {
  value: BlogLayout;
  onChange: (next: BlogLayout) => void;
  onSave: (note: string) => void;
  saving: boolean;
  savedAt: string | null;
  images: { url: string }[] | null;
  onUpload: (f: File) => Promise<string | null>;
}) {
  const [open, setOpen] = useState<string | null>(null);
  const [drag, setDrag] = useState<number | null>(null);
  const [note, setNote] = useState('');
  const [picking, setPicking] = useState<string | null>(null);

  const set = (patch: Partial<BlogLayout>) => onChange(cleanLayout({ ...value, ...patch }));
  const setTheme = (patch: Partial<Theme>) => set({ theme: { ...value.theme, ...patch } });
  const setBlock = (id: string, patch: Partial<Block>) =>
    set({ blocks: value.blocks.map((b) => (b.id === id ? { ...b, ...patch } : b)) });
  const setProp = (id: string, key: string, v: string | number | boolean) => {
    const b = value.blocks.find((x) => x.id === id);
    if (b) setBlock(id, { props: { ...(b.props ?? {}), [key]: v } });
  };

  const move = (from: number, to: number) => {
    if (to < 0 || to >= value.blocks.length || from === to) return;
    const next = value.blocks.slice();
    next.splice(to, 0, ...next.splice(from, 1));
    set({ blocks: next });
  };

  const add = (kind: BlockKind) => {
    const id = `${kind}-${Math.random().toString(36).slice(2, 6)}`;
    set({ blocks: [...value.blocks, { id, kind }] });
    setOpen(id);
  };

  const canAdd = (Object.keys(KIND_LABEL) as BlockKind[])
    .filter((k) => !(ONCE.includes(k) && value.blocks.some((b) => b.kind === k)));

  const chip = (on: boolean) =>
    `cursor-pointer rounded-full px-2.5 py-1 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'border border-hairline text-ink-mid hover:bg-surface'}`;

  return (
    <div className="flex flex-col gap-4">
      {/* ── 모양: 기둥·폭 ── */}
      <section className="rounded-xl border border-hairline bg-paper p-4">
        <p className="text-[13px] font-bold">Shape</p>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {([['stack', 'One column'], ['rail-left', 'Sidebar left'], ['rail-right', 'Sidebar right']] as const).map(([v, label]) => (
            <button key={v} onClick={() => set({ shell: v })} className={chip(value.shell === v)}>{label}</button>
          ))}
        </div>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {([['narrow', 'Narrow'], ['normal', 'Normal'], ['wide', 'Wide']] as const).map(([v, label]) => (
            <button key={v} onClick={() => set({ width: v })} className={chip(value.width === v)}>{label}</button>
          ))}
        </div>
      </section>

      {/* ── 색·서체·모서리 ── */}
      <section className="rounded-xl border border-hairline bg-paper p-4">
        <p className="text-[13px] font-bold">Look</p>
        <div className="mt-2.5 flex flex-wrap gap-2">
          {SWATCHES.map(([bg, ink, accent]) => (
            <button
              key={bg + ink}
              onClick={() => setTheme({ bg, ink, accent })}
              aria-label={`palette ${bg}`}
              className={`size-8 cursor-pointer overflow-hidden rounded-full border-2 ${value.theme.bg === bg && value.theme.ink === ink ? 'border-ink' : 'border-hairline'}`}
              style={{ background: `linear-gradient(135deg, ${bg} 0 50%, ${ink} 50% 80%, ${accent} 80% 100%)` }}
            />
          ))}
        </div>
        <div className="mt-3 grid grid-cols-3 gap-2">
          {([['bg', 'Page'], ['ink', 'Text'], ['accent', 'Accent']] as const).map(([k, label]) => (
            <label key={k} className="flex items-center gap-1.5 text-[12px]">
              <input type="color" value={value.theme[k]} onChange={(e) => setTheme({ [k]: e.target.value } as Partial<Theme>)}
                className="size-7 cursor-pointer rounded border border-hairline bg-transparent p-0" />
              {label}
            </label>
          ))}
        </div>
        <Row label="Font">
          {([['sans', 'Sans'], ['serif', 'Serif'], ['mono', 'Mono']] as const).map(([v, l]) => (
            <button key={v} onClick={() => setTheme({ font: v })} className={chip(value.theme.font === v)}>{l}</button>
          ))}
        </Row>
        <Row label="Corners">
          {([['none', 'Sharp'], ['sm', 'Soft'], ['lg', 'Round'], ['pill', 'Pill']] as const).map(([v, l]) => (
            <button key={v} onClick={() => setTheme({ radius: v })} className={chip(value.theme.radius === v)}>{l}</button>
          ))}
        </Row>
        <Row label="Spacing">
          {([['tight', 'Tight'], ['normal', 'Normal'], ['roomy', 'Roomy']] as const).map(([v, l]) => (
            <button key={v} onClick={() => setTheme({ density: v })} className={chip(value.theme.density === v)}>{l}</button>
          ))}
        </Row>
        <Row label="Lines">
          {([['none', 'None'], ['hairline', 'Thin'], ['bold', 'Thick']] as const).map(([v, l]) => (
            <button key={v} onClick={() => setTheme({ border: v })} className={chip(value.theme.border === v)}>{l}</button>
          ))}
        </Row>
      </section>

      {/* ── 블록: 끌어서 순서 바꾸기 ── */}
      <section className="rounded-xl border border-hairline bg-paper p-4">
        <p className="text-[13px] font-bold">Blocks</p>
        <p className="mt-0.5 text-[11.5px] text-ink-soft">Drag to reorder. Click to change what it shows.</p>
        <ul className="mt-2.5 flex flex-col gap-1.5">
          {value.blocks.map((b, i) => (
            <li
              key={b.id}
              draggable
              onDragStart={() => setDrag(i)}
              onDragOver={(e) => { e.preventDefault(); if (drag !== null && drag !== i) { move(drag, i); setDrag(i); } }}
              onDragEnd={() => setDrag(null)}
              className={`rounded-lg border bg-surface ${drag === i ? 'border-ink opacity-60' : 'border-hairline'}`}
            >
              <div className="flex items-center gap-1.5 px-2 py-1.5">
                <GripVertical size={14} aria-hidden className="cursor-grab text-ink-soft" />
                <button onClick={() => setOpen(open === b.id ? null : b.id)} className="flex-1 cursor-pointer text-left text-[13px] font-semibold">
                  {KIND_LABEL[b.kind]}
                </button>
                {value.shell !== 'stack' && (
                  <button onClick={() => setBlock(b.id, { rail: !b.rail })} className={`${chip(!!b.rail)} !px-2 !py-0.5 !text-[10.5px]`}>
                    side
                  </button>
                )}
                <button onClick={() => move(i, i - 1)} aria-label="Move up" className="cursor-pointer p-0.5 text-ink-soft hover:text-ink"><ChevronUp size={14} /></button>
                <button onClick={() => move(i, i + 1)} aria-label="Move down" className="cursor-pointer p-0.5 text-ink-soft hover:text-ink"><ChevronDown size={14} /></button>
                {b.kind !== 'posts' && (
                  <button onClick={() => set({ blocks: value.blocks.filter((x) => x.id !== b.id) })} aria-label="Remove" className="cursor-pointer p-0.5 text-ink-soft hover:text-accent-deep"><Trash2 size={13} /></button>
                )}
              </div>

              {open === b.id && (
                <div className="border-t border-hairline px-3 py-2.5">
                  <BlockSettings
                    block={b}
                    setProp={(k, v) => setProp(b.id, k, v)}
                    onPickImage={() => setPicking(b.id)}
                  />
                </div>
              )}
            </li>
          ))}
        </ul>

        <details className="mt-3">
          <summary className={`${BUTTON.ghost} inline-flex cursor-pointer items-center gap-1.5`}><Plus size={13} aria-hidden /> Add a block</summary>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {canAdd.map((k) => (
              <button key={k} onClick={() => add(k)} className={chip(false)}>{KIND_LABEL[k]}</button>
            ))}
          </div>
        </details>
      </section>

      {/* ── 그림 고르기 ── */}
      {picking && (
        <section className="rounded-xl border border-hairline bg-paper p-4">
          <div className="flex items-center justify-between">
            <p className="text-[13px] font-bold">Pick a picture</p>
            <button onClick={() => setPicking(null)} aria-label="Close" className="cursor-pointer text-ink-soft hover:text-ink"><X size={14} /></button>
          </div>
          <label className={`${BUTTON.ghost} mt-2 inline-flex cursor-pointer items-center gap-1.5`}>
            <ImagePlus size={13} aria-hidden /> Upload
            <input
              type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="hidden"
              onChange={async (e) => {
                const f = e.target.files?.[0]; e.target.value = '';
                if (!f) return;
                const url = await onUpload(f);
                if (url) applyImage(value, picking, url, setProp);
              }}
            />
          </label>
          {images?.length ? (
            <div className="mt-2 grid max-h-44 grid-cols-4 gap-2 overflow-y-auto">
              {images.map((im) => (
                <button key={im.url} onClick={() => applyImage(value, picking, im.url, setProp)} className="cursor-pointer overflow-hidden rounded border border-hairline hover:border-ink">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={im.url} alt="" className="aspect-square w-full object-cover" />
                </button>
              ))}
            </div>
          ) : <p className="mt-2 text-[12px] text-ink-soft">Nothing uploaded yet.</p>}
        </section>
      )}

      {/* ── 저장 ── */}
      <section className="rounded-xl border border-hairline bg-paper p-4">
        <input
          value={note} onChange={(e) => setNote(e.target.value)} maxLength={200}
          placeholder="What you changed today (optional)"
          className="w-full rounded-lg border border-hairline bg-surface px-3 py-2 text-[13.5px] outline-none focus:border-ink"
        />
        <div className="mt-2.5 flex flex-wrap items-center gap-3">
          <button onClick={() => { onSave(note); setNote(''); }} disabled={saving}
            className={`${BUTTON.primary} inline-flex items-center gap-1.5 disabled:opacity-50`}>
            <Save size={14} aria-hidden /> {saving ? 'Saving…' : 'Save'}
          </button>
          <button onClick={() => set(DEFAULT_LAYOUT)} className={BUTTON.ghost}>Reset</button>
          {savedAt && <span className="text-[12.5px] text-ink-soft">Saved {savedAt}</span>}
        </div>
      </section>
    </div>
  );
}

function applyImage(
  layout: BlogLayout, blockId: string, url: string,
  setProp: (id: string, key: string, v: string | number | boolean) => void,
) {
  const b = layout.blocks.find((x) => x.id === blockId);
  if (!b) return;
  setProp(blockId, b.kind === 'banner' ? 'image' : 'src', url);
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="mt-2.5">
      <p className="mb-1 font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">{label}</p>
      <div className="flex flex-wrap gap-1.5">{children}</div>
    </div>
  );
}

function BlockSettings({ block, setProp, onPickImage }: {
  block: Block;
  setProp: (key: string, v: string | number | boolean) => void;
  onPickImage: () => void;
}) {
  const p = block.props ?? {};
  const chip = (on: boolean) =>
    `cursor-pointer rounded-full px-2.5 py-1 text-[12px] font-bold ${on ? 'bg-ink text-paper' : 'border border-hairline text-ink-mid hover:bg-surface'}`;
  const field = 'w-full rounded-lg border border-hairline bg-surface px-2.5 py-1.5 text-[13px] outline-none focus:border-ink';

  switch (block.kind) {
    case 'posts':
      return (
        <>
          <Row label="How posts look">
            {([['grid', 'Cards'], ['magazine', 'Magazine'], ['list', 'List'], ['index', 'Titles only']] as const).map(([v, l]) => (
              <button key={v} onClick={() => setProp('view', v)} className={chip((p.view ?? 'grid') === v)}>{l}</button>
            ))}
          </Row>
          {(p.view ?? 'grid') === 'grid' && (
            <Row label="Columns">
              {[1, 2, 3].map((n) => (
                <button key={n} onClick={() => setProp('columns', n)} className={chip(Number(p.columns ?? 3) === n)}>{n}</button>
              ))}
            </Row>
          )}
          <Row label="Show">
            <button onClick={() => setProp('cover', p.cover === false)} className={chip(p.cover !== false)}>Covers</button>
            <button onClick={() => setProp('excerpt', p.excerpt === false)} className={chip(p.excerpt !== false)}>Excerpts</button>
            <button onClick={() => setProp('topics', p.topics === false)} className={chip(p.topics !== false)}>Topic tabs</button>
          </Row>
        </>
      );

    case 'intro':
      return (
        <>
          <Row label="Show">
            <button onClick={() => setProp('show_avatar', p.show_avatar === false)} className={chip(p.show_avatar !== false)}>Avatar</button>
            <button onClick={() => setProp('show_follows', p.show_follows === false)} className={chip(p.show_follows !== false)}>Follower counts</button>
          </Row>
          <Row label="Align">
            {([['left', 'Left'], ['center', 'Centre']] as const).map(([v, l]) => (
              <button key={v} onClick={() => setProp('align', v)} className={chip((p.align ?? 'left') === v)}>{l}</button>
            ))}
          </Row>
        </>
      );

    case 'banner':
      return (
        <>
          <input value={String(p.text ?? '')} onChange={(e) => setProp('text', e.target.value)} maxLength={400}
            placeholder="One line across the top" className={field} />
          <Row label="Height">
            {([['sm', 'Short'], ['md', 'Medium'], ['lg', 'Tall']] as const).map(([v, l]) => (
              <button key={v} onClick={() => setProp('height', v)} className={chip((p.height ?? 'md') === v)}>{l}</button>
            ))}
          </Row>
          <Row label="Background">
            <button onClick={onPickImage} className={chip(false)}>Pick a picture</button>
            {p.image ? <button onClick={() => setProp('image', '')} className={chip(false)}>Remove</button> : null}
          </Row>
        </>
      );

    case 'text':
      return (
        <>
          <textarea value={String(p.body ?? '')} onChange={(e) => setProp('body', e.target.value)} rows={4} maxLength={2000}
            placeholder="Write something" className={field} />
          <Row label="Align">
            {([['left', 'Left'], ['center', 'Centre']] as const).map(([v, l]) => (
              <button key={v} onClick={() => setProp('align', v)} className={chip((p.align ?? 'left') === v)}>{l}</button>
            ))}
          </Row>
        </>
      );

    case 'image':
      return (
        <>
          <Row label="Picture"><button onClick={onPickImage} className={chip(false)}>{p.src ? 'Change' : 'Pick one'}</button></Row>
          <input value={String(p.caption ?? '')} onChange={(e) => setProp('caption', e.target.value)} maxLength={200}
            placeholder="Caption (optional)" className={`${field} mt-2`} />
          <Row label="Size">
            <button onClick={() => setProp('full', p.full !== true)} className={chip(p.full === true)}>Full width</button>
          </Row>
        </>
      );

    case 'links':
      return (
        <>
          <p className="mb-1 text-[11.5px] text-ink-soft">One per line — name, then the address after a |</p>
          <textarea value={String(p.items ?? '')} onChange={(e) => setProp('items', e.target.value)} rows={4} maxLength={1200}
            placeholder={'My other site|https://example.com'} className={field} />
        </>
      );

    case 'divider':
      return (
        <Row label="Style">
          {([['line', 'Line'], ['dots', 'Dots'], ['space', 'Just space']] as const).map(([v, l]) => (
            <button key={v} onClick={() => setProp('style', v)} className={chip((p.style ?? 'line') === v)}>{l}</button>
          ))}
        </Row>
      );

    case 'guestbook':
      return (
        <input value={String(p.title ?? '')} onChange={(e) => setProp('title', e.target.value)} maxLength={60}
          placeholder="Guestbook" className={field} />
      );

    default:
      return null;
  }
}
