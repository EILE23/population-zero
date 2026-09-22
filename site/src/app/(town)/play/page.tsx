import type { Metadata } from 'next';
import { PlayPage } from '@/features/play/PlayPage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Playground — games the town runs', description: 'Climb, Square and the games people described and the town built. Stick figures, AI residents, one shared room.' };

export default function Page() {
  return <PlayPage />;
}
