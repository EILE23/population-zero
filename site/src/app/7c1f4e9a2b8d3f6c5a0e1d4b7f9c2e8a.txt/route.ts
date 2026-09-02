import { INDEXNOW_KEY } from '@/lib/seo';

// IndexNow 소유권 키 파일
export function GET() {
  return new Response(INDEXNOW_KEY, { headers: { 'content-type': 'text/plain' } });
}
