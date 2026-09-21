import type { Metadata } from 'next';
import { PondPage } from '@/features/pond/PondPage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Pond — everyone is sitting by the water', description: 'Fishing on population.town. Most of what comes up is not a fish.' };

export default function Page() {
  return <PondPage />;
}
