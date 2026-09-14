import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Animated, Easing, Pressable, StyleSheet, type PressableProps, type StyleProp, type ViewStyle } from 'react-native';
import { theme } from '@/theme';

/** 누른 자리에서 퍼져 나가는 잔상 한 겹 */
function Ring({ id, radius, color, onDone }: { id: number; radius: number; color: string; onDone: (id: number) => void }) {
  const anim = useMemo(() => new Animated.Value(0), []);
  // 끝났을 때 부를 함수는 렌더마다 새로 만들어진다 — 참조로 붙들어야 애니메이션이 도중에 다시 시작하지 않는다
  const done = useRef(onDone);
  useEffect(() => { done.current = onDone; });

  // 마운트되자마자 한 번 퍼지고 사라진다 — 상태를 들고 있을 이유가 없다
  useEffect(() => {
    Animated.timing(anim, {
      toValue: 1,
      duration: 420,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start(({ finished }) => { if (finished) done.current(id); });
  }, [anim, id]);

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        s.ring,
        {
          borderRadius: radius,
          borderColor: color,
          opacity: anim.interpolate({ inputRange: [0, 0.2, 1], outputRange: [0.45, 0.35, 0] }),
          transform: [{ scale: anim.interpolate({ inputRange: [0, 1], outputRange: [0.85, 1.55] }) }],
        },
      ]}
    />
  );
}

/**
 * 눌리는 모든 것의 기본 반응.
 *
 * 색만 살짝 바뀌는 것으로는 눌렸는지 알기 어렵다 — 손가락 아래에서 잠깐 가라앉았다가
 * 살짝 넘겨 튀어 오르고(overshoot), 중요한 버튼은 잔상 한 겹이 퍼져 나간다.
 * 기본값이 되어야 하는 동작이라 화면마다 만들지 않고 여기 한 곳에 둔다.
 */
export function Tap({ children, style, scale = 0.96, ripple = false, rippleRadius = 19, disabled, onPress, ...props }: Omit<PressableProps, 'children' | 'style'> & {
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  /** 얼마나 가라앉을지 — 큰 카드는 조금만, 작은 버튼은 더 깊게 */
  scale?: number;
  /** 누르는 순간 퍼지는 잔상 — 보내기처럼 '일이 일어난' 버튼에만 */
  ripple?: boolean;
  /** 잔상의 모서리 — 동그란 버튼이면 반지름, 카드면 카드의 모서리값 */
  rippleRadius?: number;
}) {
  const anim = useMemo(() => new Animated.Value(1), []);
  const [rings, setRings] = useState<number[]>([]);
  const seq = useRef(0);

  const down = () => {
    Animated.timing(anim, { toValue: scale, duration: 80, useNativeDriver: true }).start();
  };
  const up = () => {
    // 제자리로 돌아올 때 살짝 넘겼다 오면 '튀어 올랐다'로 읽힌다
    Animated.spring(anim, { toValue: 1, friction: 3.6, tension: 200, useNativeDriver: true }).start();
  };

  return (
    <Pressable
      onPressIn={down}
      onPressOut={up}
      onPress={(e) => {
        if (ripple) {
          seq.current += 1;
          const id = seq.current;
          setRings((prev) => [...prev, id]);
        }
        onPress?.(e);
      }}
      disabled={disabled}
      {...props}
    >
      <Animated.View style={[style, { transform: [{ scale: anim }] }, disabled && s.off]}>
        {rings.map((id) => (
          <Ring
            key={id}
            id={id}
            radius={rippleRadius}
            color={theme.color.accent}
            onDone={(done) => setRings((prev) => prev.filter((x) => x !== done))}
          />
        ))}
        {children}
      </Animated.View>
    </Pressable>
  );
}

const s = StyleSheet.create({
  ring: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    borderWidth: 2,
  },
  off: { opacity: 0.5 },
});
