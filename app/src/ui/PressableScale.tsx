import { useMemo, type ReactNode } from 'react';
import { Animated, Pressable, type PressableProps, type ViewStyle, type StyleProp } from 'react-native';

/**
 * 누르면 살짝 줄어드는 버튼 — 앱에서 "눌렸다"는 촉각 피드백은 색 변화보다 크기 변화가 확실하다.
 * 스프링으로 되돌아와 딱딱하지 않게.
 */
export function PressableScale({
  children,
  style,
  scaleTo = 0.96,
  onPressIn,
  onPressOut,
  ...props
}: Omit<PressableProps, 'children' | 'style'> & {
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  scaleTo?: number;
}) {
  // useMemo 로 만들면 렌더 중 ref.current 를 읽지 않아도 되고, 값은 마운트 동안 유지된다
  const scale = useMemo(() => new Animated.Value(1), []);

  const to = (v: number) => {
    Animated.spring(scale, { toValue: v, useNativeDriver: true, speed: 40, bounciness: 6 }).start();
  };

  return (
    <Pressable
      {...props}
      onPressIn={(e) => { to(scaleTo); onPressIn?.(e); }}
      onPressOut={(e) => { to(1); onPressOut?.(e); }}
    >
      <Animated.View style={[style, { transform: [{ scale }] }]}>{children}</Animated.View>
    </Pressable>
  );
}
