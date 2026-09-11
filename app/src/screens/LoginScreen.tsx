import { useState } from 'react';
import { ActivityIndicator, KeyboardAvoidingView, Linking, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { API_BASE, ApiError, login, type Me } from '@/api';
import { theme } from '@/theme';

/** 웹 계정 그대로 로그인 — 성공하면 앱·웹이 같은 사용자로 동작한다 */
export function LoginScreen({ onDone }: { onDone: (me: Me) => void }) {
  const [handle, setHandle] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [focused, setFocused] = useState<'handle' | 'password' | null>(null);

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
        <Text style={s.brand}>poz</Text>

        {/* 밑줄형 입력 — 상자 없이 선 하나. 포커스되면 선이 진해진다 */}
        <TextInput
          value={handle}
          onChangeText={setHandle}
          onFocus={() => setFocused('handle')}
          onBlur={() => setFocused(null)}
          placeholder="Handle"
          placeholderTextColor={theme.color.inkSoft}
          autoCapitalize="none"
          autoCorrect={false}
          style={[s.input, focused === 'handle' && s.inputFocused]}
          returnKeyType="next"
        />
        <TextInput
          value={password}
          onChangeText={setPassword}
          onFocus={() => setFocused('password')}
          onBlur={() => setFocused(null)}
          placeholder="Password"
          placeholderTextColor={theme.color.inkSoft}
          secureTextEntry
          autoCapitalize="none"
          style={[s.input, focused === 'password' && s.inputFocused]}
          returnKeyType="go"
          onSubmitEditing={submit}
        />

        {error ? <Text style={s.error}>{error}</Text> : null}

        <Pressable onPress={submit} disabled={busy} style={({ pressed }) => [s.button, (pressed || busy) && s.buttonPressed]}>
          {busy ? <ActivityIndicator color={theme.color.paper} /> : <Text style={s.buttonText}>Sign in</Text>}
        </Pressable>

        {/* 가입·비밀번호 찾기는 아직 앱 화면이 없다 — 웹으로 보낸다 */}
        <View style={s.links}>
          <Pressable onPress={() => Linking.openURL(`${API_BASE}/login?mode=signup`)} hitSlop={8}>
            <Text style={s.link}>Create account</Text>
          </Pressable>
          <Text style={s.linkDivider}>|</Text>
          <Pressable onPress={() => Linking.openURL(`${API_BASE}/forgot`)} hitSlop={8}>
            <Text style={s.link}>Forgot password</Text>
          </Pressable>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: theme.space(7) },
  overline: { fontSize: 10.5, letterSpacing: 2, color: theme.color.inkSoft, fontWeight: '700', textAlign: 'center' },
  brand: {
    fontSize: 52,
    fontWeight: '800',
    color: theme.color.ink,
    letterSpacing: -1.5,
    textAlign: 'center',
    marginTop: theme.space(2),
    marginBottom: theme.space(10),
  },
  input: {
    borderBottomWidth: 1,
    borderBottomColor: theme.color.hairline,
    paddingVertical: theme.space(3.5),
    fontSize: 16,
    color: theme.color.ink,
    marginBottom: theme.space(5),
  },
  inputFocused: { borderBottomColor: theme.color.accent, borderBottomWidth: 1.5 },
  error: { color: theme.color.ink, fontWeight: '700', fontSize: 13, marginBottom: theme.space(3), marginTop: -theme.space(2) },
  button: {
    backgroundColor: theme.color.ink,
    borderRadius: theme.radius.md,
    paddingVertical: theme.space(4.5),
    alignItems: 'center',
    marginTop: theme.space(2),
  },
  buttonPressed: { opacity: 0.85 },
  buttonText: { color: theme.color.paper, fontWeight: '700', fontSize: 15.5 },
  links: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: theme.space(3), marginTop: theme.space(7) },
  link: { fontSize: 12.5, color: theme.color.accentDeep, fontWeight: '600' },
  linkDivider: { fontSize: 12, color: theme.color.inkFaint },
});
