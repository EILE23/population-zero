'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeftRight, GripVertical, ImagePlus, Plus, RotateCcw, Save, Settings2, Trash2, Undo2, X } from 'lucide-react';
import { BUTTON } from '@/components/button-styles';
import { BlogCanvas } from '@/features/blog/components/BlogCanvas';
import { cleanLayout, DEFAULT_LAYOUT, themeVars, type Block, type BlockKind, type BlogLayout, type Theme } from '@/lib/blog-layout';
import type { ProfileData } from '@/features/blog/types';
import { BlockSettings, CommonSettings, KIND_LABEL, ONCE, Row } from './BlockSettings';

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
  // 되돌리기 — 잘못 끌었을 때 돌아올 수단이 없는 게 편집기에서 제일 답답한 일이다
  const [past, setPast] = useState<BlogLayout[]>([]);
  const [picked, setPicked] = useState<string | null>(null);
  const [drag, setDrag] = useState<string | null>(null);
  const [over, setOver] = useState<{ id: string; pos: 'before' | 'after' } | null>(null);
  const [insertAt, setInsertAt] = useState<number | null>(null);
  const [picking, setPicking] = useState<string | null>(null);
  const [images, setImages] = useState<{ url: string }[] | null>(null);
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [message, setMessage] = useState('');
  const router = useRouter();
  // 블로그 제목은 배치가 아니라 계정의 값이다(앱도 같은 값을 본다) — 여기서 바꾸고 users.blog_title 에 쓴다
  const [title, setTitle] = useState(data.owner.blog_title ?? '');

  const set = (patch: Partial<BlogLayout>) => {
    setPast((p) => [...p.slice(-19), layout]);
    setLayout(cleanLayout({ ...layout, ...patch }));
  };
  const undo = () => {
    setPast((p) => {
      if (!p.length) return p;
      setLayout(p[p.length - 1]);
      return p.slice(0, -1);
    });
  };
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z' && !e.shiftKey) {
        const el = document.activeElement;
        if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) return; // 글자 입력 중엔 브라우저 몫
        e.preventDefault();
        undo();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });
  const setTheme = (patch: Partial<Theme>) => set({ theme: { ...layout.theme, ...patch } });
  const setProp = (id: string, key: string, v: string | number | boolean) =>
    set({ blocks: layout.blocks.map((b) => (b.id === id ? { ...b, props: { ...(b.props ?? {}), [key]: v } } : b)) });

  /** 기둥에 끌어다 놓기 — 사이드바로 넘기면 그 블록이 사이드바 블록이 된다 */
  const dropZone = (zone: 'rail' | 'main') => ({
    onDragOver: (e: React.DragEvent) => { e.preventDefault(); },
    onDrop: (e: React.DragEvent) => {
      e.preventDefault();
      if (!drag) return;
      const want = zone === 'rail';
      const b = layout.blocks.find((x) => x.id === drag);
      if (!b || !!b.rail === want) return;
      set({ blocks: layout.blocks.map((x) => (x.id === drag ? { ...x, rail: want } : x)) });
    },
  });

  /**
   * 끌어 옮기기 — 지나갈 때 바로 자리를 바꾸면 화면이 계속 튀어서 어디에 놓이는지 알 수 없다.
   * 그래서 놓일 자리를 선으로 먼저 보여주고(over), 놓을 때 한 번 옮긴다.
   */
  const commitDrop = () => {
    if (!drag || !over) { setDrag(null); setOver(null); return; }
    const from = layout.blocks.findIndex((b) => b.id === drag);
    let to = layout.blocks.findIndex((b) => b.id === over.id);
    if (from < 0 || to < 0 || over.id === drag) { setDrag(null); setOver(null); return; }
    if (over.pos === 'after') to += 1;
    if (to > from) to -= 1;
    const next = layout.blocks.slice();
    next.splice(to, 0, ...next.splice(from, 1));
    set({ blocks: next });
    setDrag(null); setOver(null);
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
      // 무엇을 바꿨는지는 고른 값에서 자동으로 적는다 — 사람에게 또 물어볼 일이 아니다
      body: JSON.stringify({ layout, note: describe(layout), shape: describe(layout) }),
    });
    // 제목이 바뀌었으면 같이 저장한다 — 배치와 제목을 따로 저장하게 만들면 사람이 한쪽을 잊는다
    if ((data.owner.blog_title ?? '') !== title.trim()) {
      await fetch('/api/me/blog-title', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ title: title.trim() }),
      }).catch(() => null);
    }
    const d = await res.json() as { ok?: boolean; message?: string };
    setSaving(false);
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not save that.'); return; }
    setSavedAt(new Date().toLocaleTimeString());
    // 라우터 캐시를 버린다 — 저장 뒤 내 블로그로 넘어갔을 때 옛 화면이 나오지 않게
    router.refresh();
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
        {/* 놓일 자리 — 끌고 있는 동안만 보이는 선 */}
        {drag && over?.id === block.id && over.pos === 'before' && <DropLine />}
        <div
          draggable
          onDragStart={(e) => { setDrag(block.id); e.dataTransfer.effectAllowed = 'move'; }}
          onDragOver={(e) => {
            e.preventDefault();
            if (!drag || drag === block.id) return;
            const box = (e.currentTarget as HTMLElement).getBoundingClientRect();
            setOver({ id: block.id, pos: e.clientY < box.top + box.height / 2 ? 'before' : 'after' });
          }}
          onDrop={(e) => { e.preventDefault(); commitDrop(); }}
          onDragEnd={commitDrop}
          onClick={(e) => { e.stopPropagation(); setPicked(on ? null : block.id); }}
          className={`group relative cursor-grab rounded-md outline-offset-2 transition-[outline-color] ${
            on ? 'outline outline-2 outline-accent' : 'outline outline-1 outline-transparent hover:outline-hairline'
          } ${drag === block.id ? 'opacity-50' : ''}`}
        >
          {/* 이름표는 블록 왼쪽 바깥에 — 위에 얹으면 주제 탭·제목을 가린다(실제로 가렸다) */}
          <div className={`absolute -top-2.5 left-0 z-10 flex -translate-y-full items-center gap-0.5 rounded-full border border-hairline bg-paper px-1.5 py-0.5 shadow-sm transition-opacity ${on ? '' : 'opacity-0 group-hover:opacity-100'}`}>
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
        {drag && over?.id === block.id && over.pos === 'after' && <DropLine />}

        {on && (
          <div className="mt-2 flex flex-col gap-2.5 rounded-xl border border-accent/40 bg-surface p-3" onClick={(e) => e.stopPropagation()}>
            {block.kind === 'header' && (
              <label className="block">
                <span className="mb-1 block font-mono text-[10px] uppercase tracking-[0.12em] text-ink-soft">Blog name</span>
                <input
                  value={title} onChange={(e) => setTitle(e.target.value)} maxLength={60}
                  placeholder={`${data.owner.handle}'s blog`}
                  className="w-full rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[14px] font-semibold outline-none focus:border-ink"
                />
              </label>
            )}
            <BlockSettings
              block={block}
              setProp={(k, v) => setProp(block.id, k, v)}
              onPickImage={() => { setPicking(block.id); void loadImages(); }}
            />
            <CommonSettings block={block} setProp={(k, v) => setProp(block.id, k, v)} />
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
        <button
          onClick={undo}
          disabled={!past.length}
          className={`${chip(false)} inline-flex items-center gap-1 disabled:opacity-40`}
          title="Undo (Ctrl+Z)"
        >
          <Undo2 size={12} aria-hidden /> Undo
        </button>
        <button onClick={() => set(DEFAULT_LAYOUT)} className={`${chip(false)} inline-flex items-center gap-1`} title="Back to the plain blog">
          <RotateCcw size={12} aria-hidden /> Reset
        </button>
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
            <Row label="Text size">
              {([['sm', 'S'], ['md', 'M'], ['lg', 'L']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ scale: v })} className={chip(layout.theme.scale === v)}>{l}</button>
              ))}
            </Row>
            <Row label="Letter spacing">
              {([['tight', 'Tight'], ['normal', 'Normal'], ['wide', 'Wide']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ tracking: v })} className={chip(layout.theme.tracking === v)}>{l}</button>
              ))}
            </Row>
            <Row label="Line height">
              {([['tight', 'Tight'], ['normal', 'Normal'], ['loose', 'Loose']] as const).map(([v, l]) => (
                <button key={v} onClick={() => setTheme({ leading: v })} className={chip(layout.theme.leading === v)}>{l}</button>
              ))}
            </Row>
            <Row label="Home link">
              {([['logo', 'POZ logo'], ['label', 'My words'], ['none', 'Hide']] as const).map(([v, l]) => (
                <button key={v} onClick={() => set({ chrome: { ...layout.chrome, home: v } })} className={chip(layout.chrome.home === v)}>{l}</button>
              ))}
            </Row>
            {layout.chrome.home === 'label' && (
              <input
                value={layout.chrome.label}
                onChange={(e) => set({ chrome: { ...layout.chrome, label: e.target.value } })}
                maxLength={24} placeholder="back"
                className="w-full rounded-lg border border-hairline bg-paper px-2.5 py-1.5 text-[13px] outline-none focus:border-ink"
              />
            )}
            <Row label="Search & buttons">
              {([['top', 'At the top'], ['bottom', 'At the bottom']] as const).map(([v, l]) => (
                <button key={v} onClick={() => set({ chrome: { ...layout.chrome, nav: v } })} className={chip(layout.chrome.nav === v)}>{l}</button>
              ))}
            </Row>
          </div>
        </details>

        <div className="ml-auto flex items-center gap-2">
          <button onClick={() => void save()} disabled={saving} className={`${BUTTON.primary} inline-flex items-center gap-1.5 !py-1.5 disabled:opacity-50`}>
            <Save size={13} aria-hidden /> {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>

      {message && <p role="alert" className="mt-2 text-[13px] font-semibold text-accent-deep">{message}</p>}
      {savedAt && !message && <p className="mt-2 text-[12.5px] text-ink-soft">Saved {savedAt} · <a className="underline" href={base}>open your blog ↗</a></p>}

      {/* ── 화면 자체가 편집면 ── */}
      <div className="mt-4 overflow-hidden rounded-xl border border-hairline">
        <div className="pz-page p-4 pt-9 sm:p-7 sm:pt-10" style={themeVars(layout.theme) as React.CSSProperties}>
          <BlogCanvas
            layout={layout}
            data={{ ...data, owner: { ...data.owner, blog_title: title || null } }}
            base={base} viewer editing blockWrap={wrapBlock} zoneProps={dropZone}
          />
        </div>
        {/* 블록 사이의 + 는 마우스를 올려야 보인다 — 처음 오는 사람이 못 찾으니 늘 보이는 줄을 하나 둔다 */}
        <div className="flex flex-wrap items-center gap-1.5 border-t border-hairline bg-surface px-4 py-3">
          <span className="mr-1 font-mono text-[10.5px] uppercase tracking-[0.12em] text-ink-soft">Add a block</span>
          {canAdd.map((k) => (
            <button
              key={k}
              onClick={() => insert(k, layout.blocks.length)}
              className="inline-flex cursor-pointer items-center gap-1 rounded-full border border-hairline bg-paper px-2.5 py-1 text-[12px] font-bold text-ink-mid hover:border-ink hover:text-ink"
            >
              <Plus size={11} aria-hidden /> {KIND_LABEL[k]}
            </button>
          ))}
          {canAdd.length === 0 && <span className="text-[12px] text-ink-soft">Everything is already on the page.</span>}
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

/** 놓일 자리 표시선 */
function DropLine() {
  return <div aria-hidden className="my-1 h-[3px] rounded-full bg-accent" />;
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
