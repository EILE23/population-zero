import { useEffect, useMemo } from 'react';
import { Animated, Easing, Pressable, StyleSheet } from 'react-native';
import { theme } from '@/theme';

const W = 46;
const H = 28;
const KNOB = 22;

/**
 * 켜고 끄는 스위치 — 직접 그린다.
 * react-native-web 의 Switch 는 thumbColor 를 무시하고 자기 기본 색(청록)을 칠해서
 * 웹 미리보기와 실기기의 색이 달라진다. 손잡이는 우리 잉크, 켜진 트랙만 강조색.
 */
export function Toggle({ value, onChange, disabled = false }: {
  value: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
}) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, {
      toValue: value ? 1 : 0,
      duration: 180,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: false, // 트랙 색이 바뀌므로 네이티브 드라이버를 쓸 수 없다
    }).start();
  }, [anim, value]);

  const trackColor = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [theme.color.surfaceDeep, theme.color.accent],
  });
  const shift = anim.interpolate({ inputRange: [0, 1], outputRange: [3, W - KNOB - 3] });

  return (
    <Pressable
      onPress={() => !disabled && onChange(!value)}
      accessibilityRole="switch"
      accessibilityState={{ checked: value, disabled }}
      hitSlop={8}
      style={disabled && s.disabled}
    >
      <Animated.View style={[s.track, { backgroundColor: trackColor }]}>
        <Animated.View style={[s.knob, { transform: [{ translateX: shift }] }]} />
      </Animated.View>
    </Pressable>
  );
}

const s = StyleSheet.create({
  track: { width: W, height: H, borderRadius: H / 2, justifyContent: 'center' },
  knob: {
    width: KNOB,
    height: KNOB,
    borderRadius: KNOB / 2,
    backgroundColor: theme.color.inkBlack,
    shadowColor: theme.color.inkBlack,
    shadowOpacity: 0.25,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 1 },
    elevation: 2,
  },
  disabled: { opacity: 0.5 },
});
