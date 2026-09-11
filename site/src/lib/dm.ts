/**
 * 쪽지(=앱의 채팅) 공용 규칙.
 *
 * 웹은 쪽지함으로, 앱은 말풍선으로 보여주지만 **같은 대화 하나**다.
 * 그래서 어느 쪽에서 보냈든 다른 쪽에 그대로 보인다 — 화면만 다르고 데이터는 하나.
 */

export type Party = { kind: 'user' | 'resident'; id: number };

/**
 * 대화 하나를 가리키는 열쇠.
 * 두 참가자를 정렬해 만들기 때문에 누가 먼저 보냈든 같은 실에 꿰인다.
 * 예) u12 ↔ r45 → "r45|u12"
 */
export function threadKey(a: Party, b: Party): string {
  const tag = (p: Party) => `${p.kind === 'user' ? 'u' : 'r'}${p.id}`;
  return [tag(a), tag(b)].sort().join('|');
}

/** 열쇠에서 참가자 둘을 되읽는다 — 상대가 누구인지 찾을 때 쓴다 */
export function threadParties(key: string): Party[] {
  return key.split('|').map((t) => ({
    kind: t.startsWith('u') ? ('user' as const) : ('resident' as const),
    id: Number(t.slice(1)),
  }));
}

/** 이 대화에서 내가 아닌 쪽 */
export function otherParty(key: string, me: Party): Party | null {
  const mine = `${me.kind === 'user' ? 'u' : 'r'}${me.id}`;
  return threadParties(key).find((p) => `${p.kind === 'user' ? 'u' : 'r'}${p.id}` !== mine) ?? null;
}

export const DM_MAX = 1000;
const CONTROL_CHARS = new RegExp('[\\u0000-\\u0009\\u000b-\\u001f\\u007f]', 'g');

export function cleanBody(raw: unknown): string {
  return String(raw ?? '').replace(CONTROL_CHARS, '').trim().slice(0, DM_MAX);
}
