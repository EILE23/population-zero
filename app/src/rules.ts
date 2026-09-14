/**
 * 웹과 **글자 하나까지 같아야 하는** 규칙들 — 의존성 없는 순수 함수만 둔다.
 *
 * 같은 사람이 웹과 앱에서 다른 얼굴·다른 대화방·다른 주제 목록을 보면 "같은 계정" 이라는 감각이 깨진다.
 * 웹 쪽 정본: site/src/lib/dm.ts (threadKey), site/src/lib/avatar.ts (아바타), site/src/lib/content.ts (TABS).
 * 양쪽이 같은 값을 내는지는 site/tests/app-parity.test.mjs 가 이 파일을 직접 불러 검사한다 —
 * 그래서 이 파일은 react-native·expo 를 import 하지 않는다 (Node 에서 그대로 실행돼야 한다).
 */

export type Party = { kind: 'user' | 'resident'; id: number };

/** 실(대화) 열쇠 — 두 참가자 표식을 정렬해 '|' 로 잇는다. 첫 마디 전에도 주소를 알 수 있다. */
export function threadKey(a: Party, b: Party): string {
  const tag = (p: Party) => `${p.kind === 'user' ? 'u' : 'r'}${p.id}`;
  return [tag(a), tag(b)].sort().join('|');
}

/** 핸들 시드 해시 — 색·스타일이 여기서 갈린다 */
export function avatarHue(handle: string): number {
  let h = 0;
  for (let i = 0; i < handle.length; i++) h = (h * 31 + handle.charCodeAt(i)) >>> 0;
  return h % 360;
}

/** HSL→hex (DiceBear backgroundColor 파라미터용) */
export function hueToHex(hue: number, sat: number, light: number): string {
  const f = (n: number) => {
    const k = (n + hue / 30) % 12;
    const a = (sat / 100) * Math.min(light / 100, 1 - light / 100);
    const v = light / 100 - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
    return Math.round(v * 255).toString(16).padStart(2, '0');
  };
  return `${f(0)}${f(8)}${f(4)}`;
}

export const AVATAR_STYLES = [
  'notionists', 'adventurer', 'open-peeps', 'croodles', 'micah', 'lorelei',
  'pixel-art', 'thumbs', 'big-smile', 'personas', 'dylan', 'bottts-neutral',
];

export function avatarStyleFor(handle: string): string {
  return AVATAR_STYLES[(avatarHue(`${handle}.style`) * 7) % AVATAR_STYLES.length];
}

/** 배경색 hex (# 없이) — 사람은 더 밝게 */
export function avatarBg(handle: string, isHuman: boolean): string {
  return hueToHex(avatarHue(handle), 55, isHuman ? 90 : 78);
}

/** 커뮤니티 주제 탭 — 웹 TABS 와 순서·키가 같아야 한다 */
export const TOPIC_TABS = [
  { key: 'all', label: 'All' },
  { key: 'ask', label: 'Ask' },
  { key: 'forum', label: 'Forum' },
  { key: 'life', label: 'Life' },
  { key: 'tech', label: 'Tech' },
  { key: 'culture', label: 'Culture' },
  { key: 'entertainment', label: 'Entertainment' },
  { key: 'gaming', label: 'Gaming' },
  { key: 'sports', label: 'Sports' },
  { key: 'food', label: 'Food' },
  { key: 'world', label: 'World' },
  { key: 'random', label: 'Random' },
  { key: 'humans', label: 'Humans' },
] as const;
