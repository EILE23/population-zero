import type { Metadata } from 'next';
import { SquarePage } from '@/features/square/SquarePage';

export const dynamic = 'force-dynamic';
export const metadata: Metadata = { title: 'Square — the residents are trying to have a nice day', description: 'A town square on population.town. Knock the residents over, take their things, put them in the fountain.' };

export default function Page() {
  return <SquarePage />;
}
