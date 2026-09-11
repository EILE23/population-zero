import { useEffect, useMemo } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { theme } from '@/theme';

/**
 * 아무것도 없을 때 보여주는 화면.
 * "없음"만 알리면 막다른 길이 된다 — 무엇이 없는지, 왜 없는지, 지금 뭘 하면 되는지까지 준다.
 */
export function EmptyState({ icon, title, body, actionLabel, onAction }: {
  icon: keyof typeof Feather.glyphMap;
  title: string;
  body: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  const anim = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(anim, { toValue: 1, duration: 380, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start();
  }, [anim]);
  const rise = anim.interpolate({ inputRange: [0, 1], outputRange: [12, 0] });

  return (
    <Animated.View style={[s.root, { opacity: anim, transform: [{ translateY: rise }] }]}>
      <View style={s.badge}>
        <Feather name={icon} size={22} color={theme.color.inkSoft} />
      </View>
      <Text style={s.title}>{title}</Text>
      <Text style={s.body}>{body}</Text>
      {actionLabel && onAction ? (
        <Pressable onPress={onAction} style={({ pressed }) => [s.action, pressed && s.actionPressed]}>
          <Text style={s.actionText}>{actionLabel}</Text>
        </Pressable>
      ) : null}
    </Animated.View>
  );
}

const s = StyleSheet.create({
  root: { alignItems: 'center', paddingHorizontal: theme.space(8), paddingVertical: theme.space(14) },
  badge: {
    width: 62, height: 62, borderRadius: 31,
    backgroundColor: theme.color.surfaceDeep,
    alignItems: 'center', justifyContent: 'center',
  },
  title: { fontSize: 16, fontWeight: '800', color: theme.color.ink, marginTop: theme.space(4), textAlign: 'center' },
  body: {
    fontSize: 13, lineHeight: 19, color: theme.color.inkSoft, textAlign: 'center',
    marginTop: theme.space(2),
  },
  action: {
    marginTop: theme.space(5),
    backgroundColor: theme.color.inkBlack,
    borderRadius: theme.radius.pill,
    paddingHorizontal: theme.space(6),
    paddingVertical: theme.space(3),
  },
  actionPressed: { backgroundColor: theme.color.ink },
  actionText: { color: theme.color.paper, fontSize: 13.5, fontWeight: '700' },
});
