import { useEffect, useMemo, useRef } from 'react';
import {
  Animated, Easing, Platform, Pressable, StyleSheet, Text, TextInput,
  type TextStyle,
} from 'react-native';
import { Feather } from '@expo/vector-icons';
import { theme } from '@/theme';

const NO_OUTLINE = Platform.OS === 'web' ? ({ outlineStyle: 'none' } as unknown as TextStyle) : null;

/**
 * 검색 — 돋보기에서 입력칸이 자라난다.
 * 화면을 통째로 갈아끼우면 어디서 무엇이 바뀐 건지 눈이 못 따라간다.
 * 그래서 제목은 왼쪽으로 빠지고, 누른 자리에서 칸이 늘어나며 밑줄이 우리 색으로 그어진다.
 */
export function SearchBar({ open, value, onChange, onOpen, onClose, placeholder = 'Search' }: {
  open: boolean;
  value: string;
  onChange: (v: string) => void;
  onOpen: () => void;
  onClose: () => void;
  placeholder?: string;
}) {
  const anim = useMemo(() => new Animated.Value(0), []);
  const input = useRef<TextInput>(null);

  useEffect(() => {
    Animated.timing(anim, {
      toValue: open ? 1 : 0,
      duration: open ? 260 : 200,
      easing: open ? Easing.out(Easing.cubic) : Easing.in(Easing.cubic),
      useNativeDriver: false, // 폭이 늘어나므로 레이아웃을 실제로 바꿔야 한다
    }).start(() => { if (open) input.current?.focus(); });
  }, [anim, open]);

  if (!open) {
    return (
      <Pressable onPress={onOpen} hitSlop={10} style={s.iconButton}>
        <Feather name="search" size={18} color={theme.color.ink} />
      </Pressable>
    );
  }

  const width = anim.interpolate({ inputRange: [0, 1], outputRange: ['18%', '100%'] });
  const underline = anim.interpolate({ inputRange: [0, 1], outputRange: [0, 1] });

  return (
    <Animated.View style={[s.wrap, { width, opacity: anim }]}>
      <Feather name="search" size={16} color={theme.color.inkSoft} />
      <TextInput
        ref={input}
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor={theme.color.inkFaint}
        style={[s.input, NO_OUTLINE]}
        autoCapitalize="none"
        autoCorrect={false}
        returnKeyType="search"
      />
      {value ? (
        <Pressable onPress={() => onChange('')} hitSlop={8}>
          <Feather name="x-circle" size={15} color={theme.color.inkFaint} />
        </Pressable>
      ) : null}
      <Pressable onPress={onClose} hitSlop={10}>
        <Text style={s.cancel}>Cancel</Text>
      </Pressable>
      {/* 밑줄이 왼쪽에서 오른쪽으로 그어지며 입력이 살아난다 */}
      <Animated.View style={[s.underline, { transform: [{ scaleX: underline }] }]} />
    </Animated.View>
  );
}

const s = StyleSheet.create({
  iconButton: { padding: theme.space(1) },
  wrap: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(2),
    paddingVertical: theme.space(2), paddingHorizontal: theme.space(1),
  },
  input: { flex: 1, fontSize: 14.5, color: theme.color.ink, paddingVertical: theme.space(1) },
  cancel: { fontSize: 12.5, fontWeight: '600', color: theme.color.inkSoft },
  underline: {
    position: 'absolute', left: 0, right: 0, bottom: 0, height: 2,
    backgroundColor: theme.color.accent,
  },
});
