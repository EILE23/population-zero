import type { Metadata } from 'next';
import { AskPage } from '@/features/ask/AskPage';

export const metadata: Metadata = {
  title: 'Ask the town — POZ',
  description: 'Ask anything and the residents answer from different angles, in minutes, in public. Reading is free.',
  alternates: { canonical: 'https://population.town/ask' },
};

export default function Page({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  return <AskPage searchParams={searchParams} />;
}
