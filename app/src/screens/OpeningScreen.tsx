import { useEffect, useMemo } from 'react';
import { Animated, Easing, Image, StyleSheet, Text } from 'react-native';
import { theme } from '@/theme';

/**
 * 앱을 켜면 나오는 오프닝 — 인스타그램과 같은 구조다.
 * 네이티브 스플래시(정지 이미지)와 같은 배경색을 덮고 있다가, 로고가 떠오르고
 * 세션 복구가 끝나면(ready) 로고가 커지며 사라지고 그 아래 화면이 드러난다.
 * 별도 애니메이션 파일 없이 로고 PNG 한 장을 코드로 움직인다.
 */
export function OpeningScreen({ ready, onDone }: { ready: boolean; onDone: () => void }) {
  // useRef 대신 useMemo — 렌더 중 ref 접근 금지 규칙 때문
  const enter = useMemo(() => new Animated.Value(0), []);
  const exit = useMemo(() => new Animated.Value(0), []);

  // 등장: 로고가 살짝 작은 상태에서 탄력 있게 제자리를 찾는다
  useEffect(() => {
    Animated.parallel([
      Animated.timing(enter, { toValue: 1, duration: 420, easing: Easing.out(Easing.cubic), useNativeDriver: true }),
      Animated.spring(enter, { toValue: 1, friction: 6, tension: 60, useNativeDriver: true }),
    ]).start();
  }, [enter]);

  // 퇴장: 준비가 끝난 뒤에만 — 로딩이 빨라도 최소 한 박자는 보여준다
  useEffect(() => {
    if (!ready) return;
    const timer = setTimeout(() => {
      Animated.timing(exit, {
        toValue: 1,
        duration: 460,
        easing: Easing.in(Easing.cubic),
        useNativeDriver: true,
      }).start(({ finished }) => { if (finished) onDone(); });
    }, 420);
    return () => clearTimeout(timer);
  }, [ready, exit, onDone]);

  const logoScale = Animated.add(
    enter.interpolate({ inputRange: [0, 1], outputRange: [0.82, 1] }),
    exit.interpolate({ inputRange: [0, 1], outputRange: [0, 0.5] }),
  );
  const logoOpacity = Animated.multiply(
    enter,
    exit.interpolate({ inputRange: [0, 0.6, 1], outputRange: [1, 0.5, 0] }),
  );
  // 자막은 로고보다 한 박자 늦게 들어온다
  const captionOpacity = enter.interpolate({ inputRange: [0, 0.6, 1], outputRange: [0, 0, 1] });

  return (
    <Animated.View
      pointerEvents="none"
      style={[s.root, { opacity: exit.interpolate({ inputRange: [0, 0.7, 1], outputRange: [1, 1, 0] }) }]}
    >
      <Animated.View style={{ opacity: logoOpacity, transform: [{ scale: logoScale }] }}>
        <Image source={require('../../assets/poz-mark.png')} accessibilityLabel="POZ" style={s.logo} resizeMode="contain" />
      </Animated.View>
      <Animated.View style={{ opacity: Animated.multiply(captionOpacity, exit.interpolate({ inputRange: [0, 0.4], outputRange: [1, 0], extrapolate: 'clamp' })) }}>
        <Text style={s.caption}>population.town</Text>
      </Animated.View>
    </Animated.View>
  );
}

const s = StyleSheet.create({
  root: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: theme.color.surface,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10,
  },
  logo: { width: 112, height: 112 },
  caption: {
    marginTop: theme.space(6),
    fontSize: 10.5,
    letterSpacing: 3,
    fontWeight: '700',
    color: theme.color.inkSoft,
  },
});
