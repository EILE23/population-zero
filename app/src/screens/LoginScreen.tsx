import { useState } from 'react';
import { ActivityIndicator, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { ApiError, login, type Me } from '@/api';
import { theme } from '@/theme';

/** 웹 계정 그대로 로그인 — 성공하면 앱·웹이 같은 사용자로 동작한다 */
export function LoginScreen({ onDone }: { onDone: (me: Me) => void }) {
  const [handle, setHandle] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={s.inner}>
        <Text style={s.overline}>POPULATION: ZERO</Text>
        <Text style={s.title}>poz</Text>
        <Text style={s.sub}>Sign in with your population.town account.</Text>

        <TextInput
          value={handle}
          onChangeText={setHandle}
          placeholder="handle"
          placeholderTextColor={theme.color.inkFaint}
          autoCapitalize="none"
          autoCorrect={false}
          style={s.input}
          returnKeyType="next"
        />
        <TextInput
          value={password}
          onChangeText={setPassword}
          placeholder="password"
          placeholderTextColor={theme.color.inkFaint}
          secureTextEntry
          autoCapitalize="none"
          style={s.input}
          returnKeyType="go"
          onSubmitEditing={submit}
        />

        {error ? <Text style={s.error}>{error}</Text> : null}

        <Pressable onPress={submit} disabled={busy} style={({ pressed }) => [s.button, (pressed || busy) && s.buttonPressed]}>
          {busy ? <ActivityIndicator color={theme.color.paper} /> : <Text style={s.buttonText}>Sign in</Text>}
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: theme.space(7) },
  overline: { fontSize: 11, letterSpacing: 2, color: theme.color.inkSoft, fontWeight: '700' },
  title: { fontSize: 44, fontWeight: '800', color: theme.color.ink, marginTop: theme.space(1), letterSpacing: -1 },
  sub: { fontSize: 14, color: theme.color.inkMid, marginTop: theme.space(2), marginBottom: theme.space(7) },
  input: {
    backgroundColor: theme.color.paper,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    borderColor: theme.color.hairline,
    paddingHorizontal: theme.space(4),
    paddingVertical: theme.space(3.5),
    fontSize: 16,
    color: theme.color.ink,
    marginBottom: theme.space(3),
  },
  error: { color: theme.color.ink, fontWeight: '700', fontSize: 13, marginBottom: theme.space(2) },
  button: {
    backgroundColor: theme.color.ink,
    borderRadius: theme.radius.pill,
    paddingVertical: theme.space(4),
    alignItems: 'center',
    marginTop: theme.space(2),
  },
  buttonPressed: { opacity: 0.85 },
  buttonText: { color: theme.color.paper, fontWeight: '700', fontSize: 15 },
});
