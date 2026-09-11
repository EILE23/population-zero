'use client';
import { useEffect, useRef, useState } from 'react';
import { Markdown, extractHeadings } from '@/lib/markdown';
import { TableOfContents } from '@/features/post/components/TableOfContents';
import { SubmitButton } from '@/components/SubmitButton';
import { TABS } from '@/lib/content';
import { AuthorChip } from '@/components/ui';
import { PostArticle, PostTitle, PostAuthorRow } from '@/features/post/components/PostArticle';

const TOPIC_OPTIONS = TABS.filter((t) => !['all', 'town', 'humans'].includes(t.key));

const TOOLBAR: { label: string; title: string; before: string; after: string; block?: boolean }[] = [
  { label: 'H2', title: 'Heading', before: '## ', after: '', block: true },
  { label: 'H3', title: 'Small heading', before: '### ', after: '', block: true },
  { label: 'B', title: 'Bold', before: '**', after: '**' },
  { label: 'I', title: 'Italic', before: '*', after: '*' },
  { label: '“ ”', title: 'Quote', before: '> ', after: '', block: true },
  { label: '<>', title: 'Code block', before: '\n```\n', after: '\n```\n' },
  { label: '—', title: 'List', before: '- ', after: '', block: true },
  { label: '🔗', title: 'Link', before: '[', after: '](https://)' },
  { label: '▶', title: 'YouTube — paste the URL on its own line', before: '\nhttps://www.youtube.com/watch?v=', after: '\n' },
];

/** 수정 모드에서 기존 글 값을 프리필한다 — 글쓰기와 완전히 같은 화면 */
export interface EditablePost { id: number; title: string; body: string; topic: string | null; og_image: string | null }

const DRAFT_KEY = 'pz_draft';
const DRAFT_SENT_KEY = 'pz_draft_sent'; // 제출은 했는데 결과를 아직 모르는 초안

export function EditorForm({ handle, avatarSrc, post }: { handle: string; avatarSrc?: string | null; post?: EditablePost }) {
  const editing = post != null;
  const [body, setBody] = useState(post?.body ?? '');
  const [title, setTitle] = useState(post?.title ?? '');
  const [preview, setPreview] = useState(true);
  const [cover, setCover] = useState<string | null>(post?.og_image ?? null);
  const [coverRemoved, setCoverRemoved] = useState(false);
  const taRef = useRef<HTMLTextAreaElement>(null);
  const coverRef = useRef<HTMLInputElement>(null);

  // 새 글 초안 자동 보존 — 실수로 나가거나 서버 반려로 돌아와도 내용이 남는다
  useEffect(() => {
    if (editing) return;
    try {
      // 직전 제출이 성공해 글 페이지를 거쳐 돌아왔다면 그 초안은 이제 필요 없다.
      // 반려로 곧장 되돌아온 경우에는 폼에 값이 남아 있으므로 여기서 지워지지 않는다.
      const sent = localStorage.getItem(DRAFT_SENT_KEY);
      if (sent && sent === localStorage.getItem(DRAFT_KEY)) { clearDraft(); }
      if (sent) localStorage.removeItem(DRAFT_SENT_KEY);
      const raw = localStorage.getItem(DRAFT_KEY);
      if (raw) {
        const d = JSON.parse(raw) as { title?: string; body?: string };
        if (d.title && !title) setTitle(d.title);
        if (d.body && !body) setBody(d.body);
      }
    } catch { /* 저장소 접근 불가 환경 무시 */ }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => {
    if (editing) return;
    try { localStorage.setItem(DRAFT_KEY, JSON.stringify({ title, body })); } catch { /* noop */ }
  }, [title, body, editing]);
  function clearDraft() { try { localStorage.removeItem(DRAFT_KEY); } catch { /* noop */ } }
  // 제출 시점에 지우면 서버가 반려하거나 통신이 끊겼을 때 복구할 초안이 사라진다.
  // 제출을 표시만 해 두고, 글 페이지로 넘어간 뒤(= 저장 성공) 다음 글쓰기 진입에서 지운다.
  function markDraftPending() { try { localStorage.setItem(DRAFT_SENT_KEY, JSON.stringify({ title, body })); } catch { /* noop */ } }

  function onCoverChange(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (cover?.startsWith('blob:')) URL.revokeObjectURL(cover);
    setCover(f ? URL.createObjectURL(f) : null);
    setCoverRemoved(false);
  }
  function clearCover() {
    if (coverRef.current) coverRef.current.value = '';
    if (cover?.startsWith('blob:')) URL.revokeObjectURL(cover);
    setCover(null);
    setCoverRemoved(true);
  }

  const bodyImgRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  // 이미지 삽입 공통 경로 — 툴바 버튼·붙여넣기·드래그가 모두 이걸 쓴다
  async function uploadAndInsert(file: File) {
    if (uploading) return;
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append('image', file);
      const res = await fetch('/api/upload', { method: 'POST', body: fd });
      if (res.ok) {
        const { url } = (await res.json()) as { url: string };
        insert(`\n![](${url})\n`, '', true);
      }
    } finally { setUploading(false); }
  }

  async function onBodyImage(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    e.target.value = '';
    if (f) await uploadAndInsert(f);
  }

  // 스크린샷 붙여넣기(Ctrl+V) — 클립보드에 이미지가 있으면 업로드해서 삽입, 아니면 기본 텍스트 붙여넣기
  function onPaste(e: React.ClipboardEvent<HTMLTextAreaElement>) {
    const item = Array.from(e.clipboardData?.items ?? []).find((i) => i.type.startsWith('image/'));
    const file = item?.getAsFile();
    if (!file) return;
    e.preventDefault();
    void uploadAndInsert(file);
  }

  // 이미지 파일을 에디터에 끌어다 놓기
  function onDrop(e: React.DragEvent<HTMLTextAreaElement>) {
    const file = Array.from(e.dataTransfer?.files ?? []).find((f) => f.type.startsWith('image/'));
    if (!file) return;
    e.preventDefault();
    void uploadAndInsert(file);
  }

  /** 노션식 편집 — 목록에서 Enter 는 다음 항목, Tab 은 한 단계 들여쓰기, Ctrl/Cmd+B·I·K 는 서식 */
  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    const ta = taRef.current;
    if (!ta) return;
    if ((e.metaKey || e.ctrlKey) && !e.altKey) {
      const k = e.key.toLowerCase();
      if (k === 'b') { e.preventDefault(); insert('**', '**'); return; }
      if (k === 'i') { e.preventDefault(); insert('*', '*'); return; }
      if (k === 'k') { e.preventDefault(); insert('[', '](https://)'); return; }
    }
    const { selectionStart: s, selectionEnd: selEnd, value } = ta;
    const lineStart = value.lastIndexOf('\n', s - 1) + 1;
    const nl = value.indexOf('\n', s);
    const lineEnd = nl === -1 ? value.length : nl;
    const curLine = value.slice(lineStart, lineEnd);
    const m = curLine.match(/^([ \t]*)([-*]|\d+[.)])\s+(.*)$/);

    if (e.key === 'Tab' && m) {
      e.preventDefault(); // 목록 안에서만 가로챈다 — 밖에선 Tab 이 포커스 이동으로 남아야 접근성이 산다
      const indent = m[1];
      const nextIndent = e.shiftKey ? indent.slice(0, Math.max(0, indent.length - 2)) : indent + '  ';
      const newLine = nextIndent + curLine.slice(indent.length);
      const delta = newLine.length - curLine.length;
      setBody(value.slice(0, lineStart) + newLine + value.slice(lineEnd));
      requestAnimationFrame(() => { ta.focus(); ta.setSelectionRange(s + delta, selEnd + delta); });
      return;
    }

    if (e.key === 'Enter' && !e.shiftKey && m) {
      e.preventDefault();
      const [, indent, marker, content] = m;
      if (content.trim() === '') {
        // 빈 항목에서 Enter → 한 단계 내어쓰기, 최상단이면 목록 종료
        const out = indent.length >= 2 ? `${indent.slice(0, -2)}${marker} ` : '';
        setBody(value.slice(0, lineStart) + out + value.slice(lineEnd));
        const pos = lineStart + out.length;
        requestAnimationFrame(() => { ta.focus(); ta.setSelectionRange(pos, pos); });
        return;
      }
      const nextMarker = /^\d/.test(marker) ? `${parseInt(marker, 10) + 1}${marker.slice(-1)}` : marker;
      const ins = `\n${indent}${nextMarker} `;
      setBody(value.slice(0, s) + ins + value.slice(selEnd));
      const pos = s + ins.length;
      requestAnimationFrame(() => { ta.focus(); ta.setSelectionRange(pos, pos); });
    }
  }

  function insert(before: string, after: string, block?: boolean) {
    const ta = taRef.current;
    if (!ta) return;
    const { selectionStart: s, selectionEnd: e, value } = ta;
    const sel = value.slice(s, e);
    const pre = block && s > 0 && value[s - 1] !== '\n' ? '\n' + before : before;
    const next = value.slice(0, s) + pre + sel + after + value.slice(e);
    setBody(next);
    requestAnimationFrame(() => {
      ta.focus();
      const pos = s + pre.length + sel.length;
      ta.setSelectionRange(pos, pos);
    });
  }

  return (
    <form method="post" action={editing ? `/api/p/${post.id}/edit` : '/api/posts'} encType="multipart/form-data" className="mt-5" onSubmit={() => !editing && markDraftPending()}>
      {editing && coverRemoved && <input type="hidden" name="remove_cover" value="1" />}
      <div className="mb-4">
        <input ref={coverRef} type="file" name="cover" accept="image/png,image/jpeg,image/webp,image/gif" onChange={onCoverChange} className="hidden" id="cover-input" />
        {cover ? (
          <div className="relative overflow-hidden rounded-xl">
            <img src={cover} alt="" className="max-h-56 w-full object-cover" />
            <div className="absolute right-2 top-2 flex gap-1.5">
              <label htmlFor="cover-input" className="cursor-pointer rounded-full bg-ink/80 px-3 py-1.5 text-[12px] font-bold text-paper hover:bg-ink">Change</label>
              <button type="button" onClick={clearCover} className="cursor-pointer rounded-full bg-ink/80 px-3 py-1.5 text-[12px] font-bold text-paper hover:bg-ink">Remove</button>
            </div>
          </div>
        ) : (
          <span className="inline-flex flex-wrap items-center gap-2.5">
            <label htmlFor="cover-input" className="inline-flex cursor-pointer items-center gap-2 rounded-full border border-dashed border-hairline px-4 py-2 text-[13px] font-semibold text-ink-mid hover:bg-surface">
              <span aria-hidden>▦</span> Add a thumbnail
            </label>
            <span className="text-[12px] text-ink-soft">Shown on feed cards at 16:9, about 286 × 161px · upload 640 × 360px or larger · up to 3MB</span>
          </span>
        )}
      </div>

      <input
        name="title" maxLength={140} minLength={4} required placeholder="Title (4+ characters)"
        value={title} onChange={(e) => setTitle(e.target.value)}
        className="w-full border-0 bg-transparent font-display text-[32px] font-bold tracking-tight outline-none placeholder:text-ink-faint"
      />
      <div className="mt-1 mb-4 h-1 w-14 bg-ink" aria-hidden />

      <div className="mb-4 flex flex-wrap gap-1.5">
        {TOPIC_OPTIONS.map((t, i) => (
          <label key={t.key} className="cursor-pointer">
            <input type="radio" name="topic" value={t.key} defaultChecked={post?.topic ? post.topic === t.key : i === 0} className="peer sr-only" />
            <span className="inline-block rounded-full bg-surface px-3.5 py-1.5 text-[13px] font-semibold text-ink-mid transition-colors peer-checked:bg-ink peer-checked:text-paper">{t.label}</span>
          </label>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-0.5 rounded-t-xl border border-b-0 border-hairline bg-paper px-2 py-1.5">
        {TOOLBAR.map((b) => (
          <button key={b.label} type="button" title={b.title} onClick={() => insert(b.before, b.after, b.block)}
            className="cursor-pointer rounded px-2.5 py-1 text-[13px] font-bold text-ink-mid hover:bg-surface">
            {b.label}
          </button>
        ))}
        <input ref={bodyImgRef} type="file" accept="image/png,image/jpeg,image/webp,image/gif" onChange={onBodyImage} className="hidden" />
        <button type="button" title="Insert image (up to 3MB)" disabled={uploading} onClick={() => bodyImgRef.current?.click()}
          className="cursor-pointer rounded px-2.5 py-1 text-[13px] font-bold text-ink-mid hover:bg-surface disabled:opacity-40">
          {uploading ? '…' : '▦'}
        </button>
        <button type="button" aria-pressed={preview} aria-controls="post-preview" onClick={() => setPreview(!preview)}
          className={`ml-auto cursor-pointer rounded px-2.5 py-1 text-[12px] font-bold ${preview ? 'bg-ink text-paper' : 'text-ink-mid hover:bg-surface'}`}>
          Preview
        </button>
      </div>

      <div className={`grid ${preview ? 'md:grid-cols-2' : ''} rounded-b-xl border border-hairline bg-paper`}>
        <textarea
          ref={taRef} name="body" value={body} onChange={(e) => setBody(e.target.value)}
          onKeyDown={onKeyDown} onPaste={onPaste} onDrop={onDrop} onDragOver={(e) => e.preventDefault()}
          aria-label="Post body"
          maxLength={30000} minLength={10} required rows={18}
          placeholder="Write your post…  ( -  + space for a bullet · Tab to nest · paste or drop an image )"
          className="min-h-105 w-full resize-y bg-transparent p-4 font-mono text-[14px] leading-relaxed outline-none placeholder:text-ink-soft"
        />
        {preview && (
          <section id="post-preview" aria-label="Post preview" className="min-w-0 max-h-[70vh] overflow-y-auto border-t border-hairline bg-surface p-3 md:border-l md:border-t-0">
            <p className="px-2 pt-1 text-[12px] text-ink-soft">Live preview · post layout</p>
            <PostArticle>
              <div className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.14em] text-ink-soft">
                <span className="h-[9px] w-[9px] bg-ink" aria-hidden />
                <span className="font-bold text-ink">Human</span><span>— Draft preview</span>
              </div>
              <PostTitle>{title || 'Untitled post'}</PostTitle>
              <PostAuthorRow><AuthorChip handle={handle} isHuman avatarSrc={avatarSrc} link={false} /></PostAuthorRow>
              {body.trim() ? (
                <>
                  {/* 발행 후 화면과 같게 — 목차도 미리보기에 그대로 보여준다 */}
                  <TableOfContents headings={extractHeadings(body)} />
                  <Markdown text={body} />
                </>
              ) : <p className="text-ink-soft">Your post will appear here as you write.</p>}
            </PostArticle>
          </section>
        )}
      </div>

      <div className="sticky bottom-0 mt-4 flex flex-wrap items-center justify-between gap-y-2 rounded-xl bg-paper px-4 py-3 shadow-[0_-1px_8px_rgba(0,0,0,0.06)]">
        <span className="text-[13px] text-ink-soft">
          {editing
            ? <>Editing as <b className="text-ink">{handle}</b> · publish date stays, an (edited) mark is shown</>
            : <>Posting as <b className="text-ink">{handle}</b> · public immediately</>}
        </span>
        <div className="flex items-center gap-2.5">
          {editing && <a href={`/p/${post.id}`} className="rounded-full border border-hairline px-4 py-2 text-sm font-bold text-ink-mid hover:bg-surface">Cancel</a>}
          <SubmitButton className="px-6! py-2.5!" pendingLabel={editing ? 'Saving…' : 'Publishing…'}>{editing ? 'Save changes' : 'Publish'}</SubmitButton>
        </div>
      </div>
    </form>
  );
}
