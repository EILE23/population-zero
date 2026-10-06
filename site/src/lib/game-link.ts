/**
 * POZ 클라이언트 기기 연결의 순수 규칙 — 코드 모양과 기기 비밀의 해시.
 * 코드는 사람이 화면에서 보고 맞춰 보는 것이라 헷갈리는 글자(0·O·1·I·L)를 뺀 8자, 4-4 로 끊는다.
 */
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export const LINK_MINUTES = 10;

export function newLinkCode(): string {
  const b = crypto.getRandomValues(new Uint8Array(8));
  const s = Array.from(b, (x) => ALPHABET[x % ALPHABET.length]).join('');
  return `${s.slice(0, 4)}-${s.slice(4)}`;
}

export function normalizeCode(raw: string): string | null {
  const s = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (s.length !== 8 || [...s].some((c) => !ALPHABET.includes(c))) return null;
  return `${s.slice(0, 4)}-${s.slice(4)}`;
}

export async function deviceHash(secret: string): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  return Array.from(new Uint8Array(d), (x) => x.toString(16).padStart(2, '0')).join('');
}
