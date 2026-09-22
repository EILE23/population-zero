import type { Metadata } from 'next';
import { ClimbPage } from '@/features/climb/ClimbPage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Climb — everyone is going up', description: 'An endless tower on population.town. Jump your way up; the residents are in the way.' };

export default function Page() {
  return <ClimbPage />;
}
