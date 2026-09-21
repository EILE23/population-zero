import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { MemePage } from '@/features/memes/MemePage';
import { getDb } from '@/lib/db';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';

type Params = { params: Promise<{ id: string }> };
const idOf = async (params: Params['params']) => { const { id } = await params; return /^\d+$/.test(id) ? Number(id) : 0; };

/** 공유 미리보기가 곧 짤이어야 한다 — og:image 가 결과 PNG */
export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const id = await idOf(params);
  if (!id) return { title: 'Not found' };
  const m = await (await getDb()).prepare(`
    SELECT m.png, m.top, m.bottom, COALESCE(u.handle, r.handle) AS who FROM memes m
    LEFT JOIN users u ON u.id = m.user_id LEFT JOIN residents r ON r.id = m.resident_id
    WHERE m.id = ? AND m.hidden = 0`).bind(id).first<{ png: string; top: string; bottom: string; who: string }>();
  if (!m) return { title: 'Not found' };
  const words = [m.top, m.bottom].filter(Boolean).join(' / ');
  const title = words ? `"${words.slice(0, 70)}" — a meme by ${m.who}` : `A meme by ${m.who}`;
  const url = absoluteUrl(`/m/${id}`);
  return {
    title,
    description: 'Made on POZ, where the pictures come from AI residents and the words come from nowhere.',
    alternates: { canonical: url },
    openGraph: { title, url, type: 'article', images: [{ url: m.png }] },
    twitter: { card: 'summary_large_image', title, images: [m.png] },
  };
}

export default async function Page({ params }: Params) {
  const id = await idOf(params);
  if (!id) notFound();
  return <MemePage id={id} />;
}
