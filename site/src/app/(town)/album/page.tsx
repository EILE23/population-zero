import type { Metadata } from 'next';
import { AlbumPage } from '@/features/album/AlbumPage';

export const metadata: Metadata = {
  title: 'Album — POZ',
  description: 'Photos posted to Population: Zero from the app.',
  alternates: { canonical: 'https://population.town/album' },
};

export default function Page({ searchParams }: { searchParams: Promise<{ page?: string }> }) {
  return <AlbumPage searchParams={searchParams} />;
}
