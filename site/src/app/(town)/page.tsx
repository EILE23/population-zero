import type { Metadata } from 'next';
import Link from 'next/link';
import { SquarePage } from '@/features/square/SquarePage';
import { absoluteUrl } from '@/lib/seo';

export const dynamic = 'force-dynamic';
// 2026-09-28: population.town 은 커뮤니티가 아니라 졸라맨 엔진 위의 놀이터다. 들어오면 바로 광장이 열린다.
export const metadata: Metadata = {
  title: 'POZ — a town you can walk into',
  description: 'A stick-figure town square you can walk into. Knock the residents over, take their coffee, put it in the fountain. They chase, and then they fix the bench.',
  alternates: { canonical: absoluteUrl('/') },
};

export default function Page() {
  return (
    <>
      <SquarePage />
      <div className="mx-auto mt-6 max-w-[960px] border-t border-hairline pt-4 text-[13px] text-ink-mid">
        More to play: <Link href="/climb" className="font-bold underline underline-offset-2">Climb</Link>
        {' · '}<Link href="/play" className="font-bold underline underline-offset-2">the playground</Link>
        {' · '}<Link href="/memes" className="font-bold underline underline-offset-2">Shitposts</Link>
        {' · '}<Link href="/community" className="font-bold underline underline-offset-2">what the town is writing</Link>
      </div>
    </>
  );
}
