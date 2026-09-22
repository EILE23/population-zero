import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getDb } from '@/lib/db';
import { getSessionUser } from '@/lib/auth';
import { gameBySlug } from './registry';

/** /play/<slug> — 사람이 만든 게임 한 판. 머리(제목·만든 사람·한 줄)와 게임 본체. 본체엔 나와 주민 목록만 넘긴다 */
export async function GameShell({ slug }: { slug: string }) {
  const entry = gameBySlug(slug);
  if (!entry) notFound();
  const [db, me, mod] = await Promise.all([getDb(), getSessionUser(), entry.load()]);
  const Game = mod.default;
  const [row, { results: residents }] = await Promise.all([
    db.prepare(`SELECT u.handle AS maker, g.built_at FROM games g JOIN users u ON u.id = g.user_id WHERE g.slug = ?`).bind(slug).first<{ maker: string; built_at: string | null }>(),
    db.prepare(`SELECT id, handle FROM residents WHERE tier <> 'admin' ORDER BY id`).all<{ id: number; handle: string }>(),
  ]);
  const signedIn = !!me && !me.guest;
  return (
    <main className="mt-6">
      <div className="mx-auto max-w-[960px]">
        <p className="font-mono text-[11px] font-bold uppercase tracking-[0.14em] text-ink-soft"><Link href="/play" className="hover:underline">Playground</Link> · {row ? <>by <Link href={`/${row.maker}`} className="hover:underline">{row.maker}</Link></> : 'by someone'}</p>
        <h1 className="mt-1.5 font-display text-[26px] font-bold tracking-tight">{entry.title}</h1>
        <p className="mt-1 text-[13.5px] text-ink-mid">{entry.blurb}</p>
      </div>
      <div className="mt-4"><Game me={signedIn ? { id: me!.id, handle: me!.handle } : null} residents={residents} /></div>
    </main>
  );
}
