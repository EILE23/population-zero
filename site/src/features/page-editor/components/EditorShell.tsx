'use client';
import { useState } from 'react';
import { BlogCanvas } from '@/features/blog/components/BlogCanvas';
import { cleanLayout, type BlogLayout } from '@/lib/blog-layout';
import type { ProfileData } from '@/features/blog/types';
import { LayoutEditor } from './LayoutEditor';

type CanvasData = Pick<ProfileData, 'owner' | 'posts' | 'topics' | 'pinnedPost' | 'seriesList' | 'followerCount' | 'followingCount' | 'isMe'>;

/**
 * 편집기 껍데기 — 왼쪽은 고르는 손, 오른쪽은 결과.
 *
 * 오른쪽은 스크린샷이나 목업이 아니라 공개 블로그가 쓰는 BlogCanvas 그 컴포넌트다. 같은 것을 그리니
 * "저장하면 이렇게 보인다"가 거짓말이 될 수 없고, iframe 도 필요 없다(프레임 헤더와 싸울 일도 없다).
 */
export function EditorShell({ initial, data, base, canSave }: {
  initial: BlogLayout;
  data: CanvasData;
  base: string;
  canSave: boolean;
}) {
  const [layout, setLayout] = useState<BlogLayout>(initial);
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [message, setMessage] = useState('');
  const [images, setImages] = useState<{ url: string }[] | null>(null);

  async function loadImages() {
    if (images) return;
    const d = await (await fetch('/api/upload', { cache: 'no-store' })).json() as { images: { url: string }[] };
    setImages(d.images ?? []);
  }

  async function upload(file: File): Promise<string | null> {
    const body = new FormData();
    body.append('image', file);
    const res = await fetch('/api/upload', { method: 'POST', body });
    const d = await res.json() as { url?: string; error?: string };
    if (!d.url) { setMessage(d.error ?? 'That image would not upload.'); return null; }
    setImages([{ url: d.url }, ...(images ?? [])]);
    return d.url;
  }

  async function save(note: string) {
    if (!canSave) { setMessage('Verify your email first — your blog is public.'); return; }
    setSaving(true); setMessage('');
    const res = await fetch('/api/pages', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ layout, note }),
    });
    const d = await res.json() as { ok?: boolean; message?: string };
    setSaving(false);
    if (!res.ok || !d.ok) { setMessage(d.message ?? 'Could not save that.'); return; }
    setSavedAt(new Date().toLocaleTimeString());
  }

  return (
    <div className="mt-6 grid gap-6 lg:grid-cols-[22rem_minmax(0,1fr)]">
      <div onPointerDown={() => void loadImages()}>
        <LayoutEditor
          value={layout}
          onChange={(next) => setLayout(cleanLayout(next))}
          onSave={save}
          saving={saving}
          savedAt={savedAt}
          images={images}
          onUpload={upload}
        />
        {message && <p role="alert" className="mt-3 text-[13px] font-semibold text-accent-deep">{message}</p>}
      </div>

      <div className="min-w-0">
        <div className="mb-1.5 flex items-baseline justify-between">
          <span className="font-mono text-[11px] uppercase tracking-[0.12em] text-ink-soft">Your blog</span>
          <a href={base} className="font-mono text-[11.5px] text-accent-deep underline underline-offset-2">open it ↗</a>
        </div>
        <div className="overflow-hidden rounded-xl border border-hairline">
          <div className="p-4 sm:p-6">
            <BlogCanvas layout={layout} data={data} base={base} viewer editing />
          </div>
        </div>
      </div>
    </div>
  );
}
