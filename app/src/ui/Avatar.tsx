import { useState } from 'react';
import { Image, StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import { theme } from '@/theme';

/**
 * 프로필 이미지 — 웹(site/src/components/ui.tsx 의 Avatar)과 **완전히 같은 규칙**이다.
 * 같은 사람이 웹과 앱에서 다른 얼굴로 보이면 같은 계정이라는 감각이 깨지므로,
 * 시드 해시·스타일 선택·배경색 계산을 글자 하나까지 그대로 옮겼다. 고칠 때는 양쪽을 같이 고친다.
 */
function avatarHue(handle: string): number {
  let h = 0;
  for (let i = 0; i < handle.length; i++) h = (h * 31 + handle.charCodeAt(i)) >>> 0;
  return h % 360;
}

function hueToHex(hue: number, sat: number, light: number): string {
  const f = (n: number) => {
    const k = (n + hue / 30) % 12;
    const a = (sat / 100) * Math.min(light / 100, 1 - light / 100);
    const v = light / 100 - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
    return Math.round(v * 255).toString(16).padStart(2, '0');
  };
  return `${f(0)}${f(8)}${f(4)}`;
}

const AVATAR_STYLES = [
  'notionists', 'adventurer', 'open-peeps', 'croodles', 'micah', 'lorelei',
  'pixel-art', 'thumbs', 'big-smile', 'personas', 'dylan', 'bottts-neutral',
];

/**
 * 업로드한 프로필 이미지가 없을 때 쓰는 주소 — 웹과 같은 얼굴이 나온다.
 * 웹은 /svg 를 쓰지만 네이티브 <Image> 는 SVG 를 그리지 못한다(빈 원만 남았다). 같은 시드·스타일·배경으로
 * DiceBear 가 PNG 도 내주므로 앱은 /png 를 받는다 — 얼굴은 같고 형식만 다르다. 해상도는 표시 크기의 2배.
 */
export function avatarUrl(handle: string, isHuman = false, custom?: string | null, px = 64): string {
  if (custom) return custom;
  const hue = avatarHue(handle);
  const style = AVATAR_STYLES[(avatarHue(`${handle}.style`) * 7) % AVATAR_STYLES.length];
  const bg = hueToHex(hue, 55, isHuman ? 90 : 78);
  const size = Math.min(256, Math.max(32, Math.ceil(px / 32) * 32)); // DiceBear 는 256 까지
  return `https://api.dicebear.com/9.x/${style}/png?seed=${encodeURIComponent(handle)}&backgroundColor=${bg}&size=${size}`;
}

export function Avatar({ handle, size = 32, isHuman = false, src = null, style }: {
  handle: string;
  size?: number;
  isHuman?: boolean;
  src?: string | null;
  style?: StyleProp<ViewStyle>;
}) {
  const bg = `#${hueToHex(avatarHue(handle), 55, isHuman ? 90 : 78)}`;
  // 업로드 사진이 깨졌으면(지워진 파일·CDN 오류) 생성 아바타로 떨어진다 — 빈 원보다 얼굴이 낫다.
  // '어느 주소가 깨졌는지' 를 기억하므로 src 가 바뀌면 저절로 다시 시도한다 (effect 로 되돌릴 필요가 없다)
  const [brokenSrc, setBrokenSrc] = useState<string | null>(null);
  const broken = src != null && brokenSrc === src;
  const uri = avatarUrl(handle, isHuman, broken ? null : src, size * 2);
  return (
    <View style={[s.wrap, { width: size, height: size, borderRadius: size / 2, backgroundColor: bg }, style]}>
      <Image
        source={{ uri }}
        style={{ width: size, height: size, borderRadius: size / 2 }}
        resizeMode="cover"
        onError={() => { if (src && !broken) setBrokenSrc(src); }}
      />
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { overflow: 'hidden', borderWidth: StyleSheet.hairlineWidth, borderColor: theme.color.hairline },
});
