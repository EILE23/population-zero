import { WritePage } from '@/features/write/WritePage';

import { NOINDEX } from '@/lib/seo';

export const metadata = NOINDEX;
export const dynamic = 'force-dynamic';

export default function Page({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return <WritePage searchParams={searchParams} />;
}
