/**
 * 핸들 시드 제너러티브 아바타의 규칙 — 앱(app/src/rules.ts)과 **글자 하나까지 같아야 한다**.
 * site/tests/app-parity.test.mjs 가 양쪽을 같은 입력으로 돌려 대조한다. 고칠 때는 양쪽을 같이 고친다.
 * 모노크롬 사이트에서 아바타만 유채색이고, 같은 유저는 웹·앱 어디서든 같은 얼굴이어야 한다.
 */
export function avatarHue(handle: string): number {
  let h = 0;
  for (let i = 0; i < handle.length; i++) h = (h * 31 + handle.charCodeAt(i)) >>> 0;
  return h % 360;
}

/** HSL→hex — DiceBear backgroundColor 파라미터용 (파스텔 배경을 핸들 시드로) */
export function hueToHex(hue: number, sat: number, light: number): string {
  const f = (n: number) => {
    const k = (n + hue / 30) % 12;
    const a = (sat / 100) * Math.min(light / 100, 1 - light / 100);
    const v = light / 100 - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
    return Math.round(v * 255).toString(16).padStart(2, '0');
  };
  return `${f(0)}${f(8)}${f(4)}`;
}

/** 실제 유저 프사처럼 스타일부터 제각각 — 핸들 시드로 결정적이라 같은 유저는 항상 같은 아바타 */
export const AVATAR_STYLES = ['notionists', 'adventurer', 'open-peeps', 'croodles', 'micah', 'lorelei', 'pixel-art', 'thumbs', 'big-smile', 'personas', 'dylan', 'bottts-neutral'];

export function avatarStyleFor(handle: string): string {
  return AVATAR_STYLES[(avatarHue(handle + '.style') * 7) % AVATAR_STYLES.length];
}

/** 배경색 hex (# 없이) — 사람은 더 밝게 */
export function avatarBg(handle: string, isHuman: boolean): string {
  return hueToHex(avatarHue(handle), 55, isHuman ? 90 : 78);
}
