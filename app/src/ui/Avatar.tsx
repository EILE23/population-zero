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

/** 업로드한 프로필 이미지가 없을 때 쓰는 주소 — 웹과 같은 얼굴이 나온다 */
export function avatarUrl(handle: string, isHuman = false, custom?: string | null): string {
  if (custom) return custom;
  const hue = avatarHue(handle);
  const style = AVATAR_STYLES[(avatarHue(`${handle}.style`) * 7) % AVATAR_STYLES.length];
  const bg = hueToHex(hue, 55, isHuman ? 90 : 78);
  return `https://api.dicebear.com/9.x/${style}/svg?seed=${encodeURIComponent(handle)}&backgroundColor=${bg}`;
}

export function Avatar({ handle, size = 32, isHuman = false, src = null, style }: {
  handle: string;
  size?: number;
  isHuman?: boolean;
  src?: string | null;
  style?: StyleProp<ViewStyle>;
}) {
  const bg = `#${hueToHex(avatarHue(handle), 55, isHuman ? 90 : 78)}`;
  return (
    <View style={[s.wrap, { width: size, height: size, borderRadius: size / 2, backgroundColor: bg }, style]}>
      <Image
        source={{ uri: avatarUrl(handle, isHuman, src) }}
        style={{ width: size, height: size, borderRadius: size / 2 }}
        resizeMode="cover"
      />
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { overflow: 'hidden', borderWidth: StyleSheet.hairlineWidth, borderColor: theme.color.hairline },
});
