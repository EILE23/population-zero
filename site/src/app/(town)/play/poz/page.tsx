import type { Metadata } from 'next';
import { PozPage } from '@/features/play/PozPage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'POZ — the town, playable', description: 'The 3D town you can walk into: residents, animals, houses you can enter, swings, fights, coffee. Runs in the browser.' };

export default function Page() {
  return <PozPage />;
}
