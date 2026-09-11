import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, Animated, Image, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { ApiError, login, type Me } from '@/api';
import { Field } from '@/ui/Field';
import { PressableScale } from '@/ui/PressableScale';
import { theme } from '@/theme';

/** 웹 계정 그대로 로그인 — 성공하면 앱·웹이 같은 사용자로 동작한다 */
export function LoginScreen({ onDone, onSignup, onForgot }: { onDone: (me: Me) => void; onSignup: () => void; onForgot: () => void }) {
  const [handle, setHandle] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 진입 애니메이션 — 로고가 살짝 떠오르며 나타난다
  const enter = useMemo(() => new Animated.Value(0), []);
  useEffect(() => {
    Animated.timing(enter, { toValue: 1, duration: 420, useNativeDriver: true }).start();
  }, [enter]);

  // 에러는 좌우로 흔들어 알린다 (웹의 shake 와 같은 언어)
  const shake = useMemo(() => new Animated.Value(0), []);
  function shakeNow() {
    shake.setValue(0);
    Animated.sequence([
      Animated.timing(shake, { toValue: 1, duration: 60, useNativeDriver: true }),
      Animated.timing(shake, { toValue: -1, duration: 60, useNativeDriver: true }),
      Animated.timing(shake, { toValue: 0.6, duration: 60, useNativeDriver: true }),
      Animated.timing(shake, { toValue: 0, duration: 60, useNativeDriver: true }),
    ]).start();
  }

  async function submit() {
    if (busy || !handle.trim() || !password) return;
    setBusy(true);
    setError(null);
    try {
      onDone(await login(handle.trim(), password));
    } catch (e) {
      const status = e instanceof ApiError ? e.status : 0;
      setError(
        status === 401 ? 'Wrong handle or password.'
        : status === 429 ? 'Too many attempts. Wait a few minutes.'
        : 'Could not reach the town. Check your connection.',
      );
      shakeNow();
    } finally {
      setBusy(false);
    }
  }

  const rise = enter.interpolate({ inputRange: [0, 1], outputRange: [16, 0] });
  const shift = shake.interpolate({ inputRange: [-1, 1], outputRange: [-6, 6] });

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Animated.View style={[s.inner, { opacity: enter, transform: [{ translateY: rise }] }]}>
        <Image source={require('../../assets/poz-logo.png')} style={s.logo} resizeMode="contain" />
        <Text style={s.overline}>POPULATION: ZERO</Text>
        <Text style={s.sub}>Sign in with your population.town account</Text>

        <Animated.View style={{ transform: [{ translateX: shift }] }}>
          <Field
            value={handle}
            onChangeText={setHandle}
            label="Handle"
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="next"
          />
          <Field
            value={password}
            onChangeText={setPassword}
            label="Password"
            secureTextEntry
            autoCapitalize="none"
            returnKeyType="go"
            onSubmitEditing={submit}
          />
        </Animated.View>

        {error ? <Text style={s.error}>{error}</Text> : null}

        <PressableScale onPress={submit} disabled={busy} style={[s.button, busy && s.buttonBusy]}>
          {busy ? <ActivityIndicator color={theme.color.paper} /> : <Text style={s.buttonText}>Sign in</Text>}
        </PressableScale>

        {/* 가입·비밀번호 찾기도 앱 안에서 처리한다 */}
        <View style={s.links}>
          <Pressable onPress={onSignup} hitSlop={12}>
            <Text style={s.link}>Create account</Text>
          </Pressable>
          <Text style={s.linkDivider}>·</Text>
          <Pressable onPress={onForgot} hitSlop={12}>
            <Text style={s.link}>Forgot password</Text>
          </Pressable>
        </View>
      </Animated.View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: theme.space(7) },
  logo: { width: 72, height: 72, alignSelf: 'center' },
  overline: {
    fontSize: 10.5, letterSpacing: 2.4, color: theme.color.inkSoft, fontWeight: '700',
    textAlign: 'center', marginTop: theme.space(4),
  },
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
  links: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: theme.space(3), marginTop: theme.space(8) },
  link: { fontSize: 12.5, color: theme.color.inkMid, fontWeight: '600' },
  linkDivider: { fontSize: 12, color: theme.color.inkFaint },
});
