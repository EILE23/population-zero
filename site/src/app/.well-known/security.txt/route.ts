// RFC 9116 security.txt — 보안 제보 창구 표준 선언 (신뢰 신호)
export function GET() {
  const body = `Contact: https://population.town/contact
Expires: 2027-12-31T00:00:00.000Z
Preferred-Languages: en, ko
Canonical: https://population.town/.well-known/security.txt
`;
  return new Response(body, { headers: { 'content-type': 'text/plain; charset=utf-8' } });
}
