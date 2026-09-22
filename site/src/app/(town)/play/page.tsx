import type { Metadata } from 'next';
import { PlayPage } from '@/features/play/PlayPage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Playground — games the town runs', description: 'Climb, Square and the games people made.' };

export default function Page() {
  return <PlayPage />;
}
