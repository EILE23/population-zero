import { useState } from 'react';
import { ActivityIndicator, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { requestPasswordReset } from '@/api';
import { Field } from '@/ui/Field';
import { PressableScale } from '@/ui/PressableScale';
import { theme } from '@/theme';

/**
 * 비밀번호 재설정 요청 — 앱에서 메일 발송까지 처리한다.
 * 실제 재설정은 메일 링크(웹)로 — 토큰이 URL 에 실리는 흐름이라 앱으로 옮기지 않는다.
 */
export function ForgotScreen({ onBack }: { onBack: () => void }) {
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (busy || !email.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await requestPasswordReset(email.trim());
      setSent(true);
    } catch {
      setError('Could not send the email. Check your connection.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView style={s.root} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={s.inner}>
        <Text style={s.title}>Reset password</Text>

        {sent ? (
          <>
            <Text style={s.sub}>
              If an account uses that email, a reset link is on its way. The link opens in your browser and expires in an hour.
            </Text>
            <PressableScale onPress={onBack} style={s.button}>
              <Text style={s.buttonText}>Back to sign in</Text>
            </PressableScale>
          </>
        ) : (
          <>
            <Text style={s.sub}>Enter the email on your account and we will send a reset link.</Text>
            <Field
              value={email}
              onChangeText={setEmail}
              label="Email"
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="email-address"
              onSubmitEditing={submit}
            />
            {error ? <Text style={s.error}>{error}</Text> : null}
            <PressableScale onPress={submit} disabled={busy} style={[s.button, busy && s.busy]}>
              {busy ? <ActivityIndicator color={theme.color.paper} /> : <Text style={s.buttonText}>Send reset link</Text>}
            </PressableScale>
            <Pressable onPress={onBack} hitSlop={12} style={s.back}>
              <Text style={s.backText}>Back to sign in</Text>
            </Pressable>
          </>
        )}
      </View>
    </KeyboardAvoidingView>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  inner: { flex: 1, justifyContent: 'center', paddingHorizontal: theme.space(7) },
  title: { fontSize: 30, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.6 },
  sub: { fontSize: 13.5, color: theme.color.inkMid, lineHeight: 20, marginTop: theme.space(2), marginBottom: theme.space(8) },
  error: { color: theme.color.accentDeep, fontWeight: '700', fontSize: 13, marginBottom: theme.space(2) },
  button: {
    backgroundColor: theme.color.inkBlack,
    borderRadius: theme.radius.md,
    paddingVertical: theme.space(4.5),
    alignItems: 'center',
    marginTop: theme.space(2),
  },
  busy: { opacity: 0.7 },
  buttonText: { color: theme.color.paper, fontWeight: '700', fontSize: 15.5 },
  back: { marginTop: theme.space(6), alignItems: 'center' },
  backText: { fontSize: 12.5, color: theme.color.inkMid, fontWeight: '600' },
});
