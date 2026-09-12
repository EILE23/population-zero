import { Children, cloneElement, isValidElement, useEffect, useMemo, type ReactNode } from 'react';
import {
  ActivityIndicator, Animated, Image, KeyboardAvoidingView, Platform,
  Linking, Pressable, ScrollView, StyleSheet, Text, View,
} from 'react-native';
import { PressableScale } from '@/ui/PressableScale';
import { theme } from '@/theme';

export type AuthLink = { label: string; onPress: () => void };

/**
 * 로그인·가입·비밀번호 찾기가 쓰는 하나의 틀.
 * 세 화면의 로고 위치, 여백, 버튼, 흔들림이 전부 같아야 해서 여기 한 곳에만 둔다.
 * 흔드는 애니메이션은 `shakeKey` 가 바뀔 때마다 한 번씩 — 부모는 에러가 날 때 이 값을 올린다.
 */
export function AuthLayout({ title, subtitle, shakeKey = 0, error, busy, submitLabel, onSubmit, links, children, footnote }: {
  title: string;
  subtitle: string;
  shakeKey?: number;
  error?: string | null;
  busy?: boolean;
  submitLabel: string;
  onSubmit: () => void;
  links: AuthLink[];
  children: ReactNode;
  footnote?: string;
}) {
  // 진입 — 로고가 살짝 떠오르며 나타난다
  const enter = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(enter, { toValue: 1, duration: 420, useNativeDriver: true }).start();
  }, [enter]);

  // 에러는 좌우로 흔들어 알린다 (웹의 shake 와 같은 언어)
  const shake = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    if (shakeKey === 0) return;
    shake.setValue(0);
    Animated.sequence([
      Animated.timing(shake, { toValue: 1, duration: 60, useNativeDriver: true }),
      Animated.timing(shake, { toValue: -1, duration: 60, useNativeDriver: true }),
      Animated.timing(shake, { toValue: 0.6, duration: 60, useNativeDriver: true }),
      Animated.timing(shake, { toValue: 0, duration: 60, useNativeDriver: true }),
    ]).start();
  }, [shake, shakeKey]);

  const rise = enter.interpolate({ inputRange: [0, 1], outputRange: [16, 0] });
  const shift = shake.interpolate({ inputRange: [-1, 1], outputRange: [-6, 6] });

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={s.scroll} keyboardShouldPersistTaps="handled">
        <Animated.View style={[s.inner, { opacity: enter, transform: [{ translateY: rise }] }]}>
          {/* 워드마크 대신 파비콘의 그 얼굴 — 앱은 좁은 화면이라 표식 하나가 더 또렷하다 */}
          <Image source={require('../../assets/poz-mark.png')} accessibilityLabel="POZ" style={s.logo} resizeMode="contain" />
          <Text style={[s.overline, !subtitle && s.overlineAlone]}>{title}</Text>
          {subtitle ? <Text style={s.sub}>{subtitle}</Text> : null}

          {/* 어느 칸에서 Enter 를 눌러도 제출된다 — 칸마다 따로 붙이면 빠뜨린 칸이 생긴다 */}
          <Animated.View style={{ transform: [{ translateX: shift }] }}>
            {Children.map(children, (child) =>
              isValidElement<{ onSubmitEditing?: () => void; returnKeyType?: string }>(child)
                ? cloneElement(child, { onSubmitEditing: onSubmit, returnKeyType: 'go' })
                : child)}
          </Animated.View>

          {error ? <Text style={s.error}>{error}</Text> : null}

          <PressableScale onPress={onSubmit} disabled={busy} style={[s.button, busy && s.buttonBusy]}>
            {busy ? <ActivityIndicator color={theme.color.paper} /> : <Text style={s.buttonText}>{submitLabel}</Text>}
          </PressableScale>

          {footnote ? <Text style={s.footnote}>{footnote}</Text> : null}

          <View style={s.links}>
            {links.map((l, i) => (
              <View key={l.label} style={s.linkRow}>
                {i > 0 ? <Text style={s.linkDivider}>·</Text> : null}
                <Pressable onPress={l.onPress} hitSlop={12}>
                  <Text style={s.link}>{l.label}</Text>
                </Pressable>
              </View>
            ))}
          </View>
          <View style={s.links}>
            {['privacy', 'terms', 'contact'].map(path => (
              <Pressable key={path} onPress={() => void Linking.openURL(`https://population.town/${path}`)}>
                <Text style={s.link}>{path === 'privacy' ? 'Privacy policy' : path === 'terms' ? 'Terms' : 'Contact'}</Text>
              </Pressable>
            ))}
          </View>
        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  scroll: { flexGrow: 1, justifyContent: 'center' },
  inner: { paddingHorizontal: theme.space(7), paddingVertical: theme.space(10) },
  logo: { width: 76, height: 76, alignSelf: 'center' },
  brandRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: theme.space(4) },
  overline: {
    fontSize: 10.5, letterSpacing: 2.4, color: theme.color.inkSoft, fontWeight: '700',
    textAlign: 'center', marginTop: theme.space(4),
  },
  // 부제가 없으면 아래 여백을 이쪽이 대신 만든다
  overlineAlone: { marginBottom: theme.space(9) },
  sub: {
    fontSize: 13.5, color: theme.color.inkMid, textAlign: 'center',
    marginTop: theme.space(2), marginBottom: theme.space(9),
  },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginBottom: theme.space(3), marginTop: -theme.space(2) },
  button: {
    backgroundColor: theme.color.inkBlack,
    borderRadius: theme.radius.md,
    paddingVertical: theme.space(4.5),
    alignItems: 'center',
    marginTop: theme.space(2),
  },
  buttonBusy: { opacity: 0.7 },
  buttonText: { color: theme.color.paper, fontWeight: '700', fontSize: 15.5, letterSpacing: 0.2 },
  footnote: { fontSize: 11.5, color: theme.color.inkSoft, lineHeight: 17, marginTop: theme.space(4), textAlign: 'center' },
  links: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: theme.space(3), marginTop: theme.space(8) },
  linkRow: { flexDirection: 'row', alignItems: 'center', gap: theme.space(3) },
  link: { fontSize: 12.5, color: theme.color.inkMid, fontWeight: '600' },
  linkDivider: { fontSize: 12, color: theme.color.inkFaint },
});
