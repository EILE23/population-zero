import { useMemo, useState } from 'react';
import { ActivityIndicator, Animated, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text } from 'react-native';
import { ApiError, signup, type Me } from '@/api';
import { Field } from '@/ui/Field';
import { PressableScale } from '@/ui/PressableScale';
import { theme } from '@/theme';

const ERROR_TEXT: Record<string, string> = {
  handle: 'Handle must be 3–20 characters: letters, numbers, - or _.',
  email: 'That email address does not look right.',
  password: 'Password must be at least 8 characters.',
  taken: 'That handle is already taken.',
  emailtaken: 'That email already has an account. Try signing in.',
  rate: 'Too many attempts. Wait a few minutes.',
};

/** 앱 안에서 가입 — 웹으로 튕기지 않는다. 가입 즉시 로그인 상태가 된다. */
export function SignupScreen({ onDone, onBack }: { onDone: (me: Me) => void; onBack: () => void }) {
  const [handle, setHandle] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      onDone(await signup({ handle: handle.trim(), email: email.trim(), password }));
    } catch (e) {
      const code = e instanceof ApiError ? e.message : '';
      setError(ERROR_TEXT[code] ?? 'Could not create the account. Check your connection.');
      shakeNow();
    } finally {
      setBusy(false);
    }
  }

  const shift = shake.interpolate({ inputRange: [-1, 1], outputRange: [-6, 6] });

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        <Text style={s.title}>Move in</Text>
        <Text style={s.sub}>Pick a handle. The residents will find you.</Text>

        <Animated.View style={{ transform: [{ translateX: shift }] }}>
          <Field value={handle} onChangeText={setHandle} label="Handle" autoCapitalize="none" autoCorrect={false} />
          <Field value={email} onChangeText={setEmail} label="Email" autoCapitalize="none" autoCorrect={false} keyboardType="email-address" />
          <Field value={password} onChangeText={setPassword} label="Password (8+ characters)" secureTextEntry autoCapitalize="none" onSubmitEditing={submit} />
        </Animated.View>

        {error ? <Text style={s.error}>{error}</Text> : null}

        <PressableScale onPress={submit} disabled={busy} style={[s.button, busy && s.busy]}>
          {busy ? <ActivityIndicator color={theme.color.paper} /> : <Text style={s.buttonText}>Create account</Text>}
        </PressableScale>

        <Text style={s.note}>
          We send a verification link to your email. You can read right away; posting unlocks once you verify.
        </Text>

        <Pressable onPress={onBack} hitSlop={12} style={s.back}>
          <Text style={s.backText}>Already have an account? Sign in</Text>
        </Pressable>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  content: { flexGrow: 1, justifyContent: 'center', paddingHorizontal: theme.space(7), paddingVertical: theme.space(10) },
  title: { fontSize: 34, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.8 },
  sub: { fontSize: 13.5, color: theme.color.inkMid, marginTop: theme.space(2), marginBottom: theme.space(8) },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginBottom: theme.space(3), marginTop: -theme.space(2) },
  button: {
    backgroundColor: theme.color.inkBlack,
    borderRadius: theme.radius.md,
    paddingVertical: theme.space(4.5),
    alignItems: 'center',
    marginTop: theme.space(2),
  },
  busy: { opacity: 0.7 },
  buttonText: { color: theme.color.paper, fontWeight: '700', fontSize: 15.5 },
  note: { fontSize: 11.5, color: theme.color.inkSoft, lineHeight: 17, marginTop: theme.space(4), textAlign: 'center' },
  back: { marginTop: theme.space(7), alignItems: 'center' },
  backText: { fontSize: 12.5, color: theme.color.inkMid, fontWeight: '600' },
});
