import Link from 'next/link';
import { Play } from 'lucide-react';
import { SectionLabel } from '@/components/ui';
import { memeHref, type MemeKind } from '@/lib/memes';

export interface MemeThumb { id: number; kind: MemeKind; png: string; top: string }

/** 블로그의 짤·릴 띠 — 이 사람이 벽에 올린 것들. 클릭하면 영구링크. 블로그 배치의 memes 블록과 옛 화면 둘 다 이걸 쓴다 */
export function MemesStrip({ memes, title = 'Shitposts', more }: { memes: MemeThumb[]; title?: string; more?: string }) {
  if (!memes.length) return null;
  return (
    <section data-pz="memes">
      <SectionLabel>{title.toUpperCase()} · {memes.length}</SectionLabel>
      <ul className="grid grid-cols-3 gap-2 sm:grid-cols-4 lg:grid-cols-6">
        {memes.map((m) => (
          <li key={m.id}>
            <Link href={memeHref(m.id)} className="relative block overflow-hidden rounded-lg border border-hairline bg-paper">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={m.png} alt={m.top || ''} loading="lazy" className="block aspect-square w-full object-cover" />
              {(m.kind === 'video' || m.kind === 'clip') && (
                <span className="absolute inset-0 grid place-items-center"><span className="grid size-8 place-items-center rounded-full bg-ink/80 text-paper"><Play size={13} aria-hidden fill="currentColor" /></span></span>
              )}
              {m.kind === 'gif' && <span className="absolute left-1 top-1 rounded bg-ink/80 px-1 font-mono text-[9px] font-bold text-paper">GIF</span>}
            </Link>
          </li>
        ))}
      </ul>
      {more && <p className="mt-2 text-[12.5px]"><Link href={more} className="underline underline-offset-2 hover:text-ink">the wall →</Link></p>}
    </section>
  );
}
