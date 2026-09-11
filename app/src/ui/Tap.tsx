import { useMemo, type ReactNode } from 'react';
import { Animated, Pressable, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';

/**
 * 눌리는 모든 것의 기본 반응.
 *
 * 색만 살짝 바뀌는 것으로는 눌렸는지 알기 어렵다 — 손가락 아래에서 잠깐 가라앉았다
 * 튀어 오르는 움직임이 있어야 "눌렸다"가 느껴진다. 기본값이 되어야 하는 동작이라
 * 화면마다 만들지 않고 여기 한 곳에 둔다.
 */
export function Tap({ children, style, scale = 0.96, disabled, onPress, ...props }: Omit<PressableProps, 'children' | 'style'> & {
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  /** 얼마나 가라앉을지 — 큰 카드는 조금만, 작은 버튼은 더 깊게 */
  scale?: number;
}) {
  const anim = useMemo(() => new Animated.Value(1), []);

  const down = () => {
    Animated.timing(anim, { toValue: scale, duration: 90, useNativeDriver: true }).start();
  };
  const up = () => {
    Animated.spring(anim, { toValue: 1, friction: 4.5, tension: 180, useNativeDriver: true }).start();
  };

  return (
    <Pressable
      onPressIn={down}
      onPressOut={up}
      onPress={onPress}
      disabled={disabled}
      {...props}
    >
      <Animated.View style={[style, { transform: [{ scale: anim }] }, disabled && { opacity: 0.5 }]}>
        {children}
      </Animated.View>
    </Pressable>
  );
}
