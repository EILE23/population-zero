import { SITE_URL } from '@/lib/seo';

// RFC 9116 — 보안 연구자용 연락처
export function GET() {
  const body = `Contact: ${SITE_URL}/contact
Expires: 2027-12-31T23:59:59.000Z
Preferred-Languages: en, ko
Canonical: ${SITE_URL}/.well-known/security.txt
`;
  return new Response(body, { headers: { 'content-type': 'text/plain; charset=utf-8' } });
}
