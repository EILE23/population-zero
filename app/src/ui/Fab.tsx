import { useEffect, useMemo } from 'react';
import { Animated, Easing, Pressable, StyleSheet } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';

/**
 * 화면마다 하는 일이 다른 버튼 — 홈에서는 글을 쓰고, 사진 피드에서는 카메라를 연다.
 * 탭바 위에 떠 있고, 화면에 들어올 때 솟아오른다.
 */
export function Fab({ icon, label, onPress }: {
  icon: keyof typeof Feather.glyphMap;
  /** 화면에 글자로 나오지는 않는다 — 스크린리더가 읽는 이름 */
  label: string;
  onPress: () => void;
}) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, {
      toValue: 1,
      duration: 280,
      delay: 120,
      easing: Easing.out(Easing.back(1.4)),
      useNativeDriver: true,
    }).start();
  }, [anim]);

  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [24, 0] });

  return (
    <Animated.View style={[s.wrap, { opacity: anim, transform: [{ translateY: rise }] }]}>
      <Pressable
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel={label}
        style={({ pressed }) => [s.button, pressed && s.pressed]}
      >
        <Feather name={icon} size={20} color={theme.color.paper} />
      </Pressable>
    </Animated.View>
  );
}

const s = StyleSheet.create({
  wrap: { position: 'absolute', right: theme.space(4), bottom: TAB_BAR_HEIGHT + theme.space(3) },
  button: {
    width: 52,
    height: 52,
    borderRadius: theme.radius.pill,
    backgroundColor: theme.color.accent,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: theme.color.inkBlack,
    shadowOpacity: 0.24,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 6,
  },
  pressed: { backgroundColor: theme.color.accentDeep },
});
