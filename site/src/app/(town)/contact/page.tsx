import { ContactPage, contactMetadata } from '@/features/contact/ContactPage';

export const metadata = contactMetadata;

export default async function Page({ searchParams }: { searchParams: Promise<{ sent?: string }> }) {
  const { sent } = await searchParams;
  return <ContactPage sent={sent === '1'} />;
}
