import type { Metadata } from 'next';
import { GameShell } from '@/features/games/GameShell';
import { gameBySlug } from '@/features/games/registry';

export const dynamic = 'force-dynamic';
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params; const g = gameBySlug(slug);
  return g ? { title: `${g.title} — a game on population.town`, description: g.blurb } : { title: 'Not a game' };
}

export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return <GameShell slug={slug} />;
}
