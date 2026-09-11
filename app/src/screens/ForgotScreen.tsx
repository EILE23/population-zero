import { useState } from 'react';
import { Text, StyleSheet } from 'react-native';
import { requestPasswordReset } from '@/api';
import { AuthLayout } from '@/ui/AuthLayout';
import { Field } from '@/ui/Field';
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
  const [shakeKey, setShakeKey] = useState(0);

  async function submit() {
    if (busy || !email.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await requestPasswordReset(email.trim());
      setSent(true);
    } catch {
      setError('Could not send the email. Check your connection.');
      setShakeKey((k) => k + 1);
    } finally {
      setBusy(false);
    }
  }

  if (sent) {
    return (
      <AuthLayout
        title="CHECK YOUR EMAIL"
        subtitle="If an account uses that address, the link is on its way."
        submitLabel="Back to sign in"
        onSubmit={onBack}
        links={[]}
        footnote="It opens in your browser and expires in an hour."
      >
        <Text style={s.sentTo}>{email.trim()}</Text>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout
      title="FORGOT YOUR PASSWORD"
      subtitle="We will send a link to the email on your account."
      shakeKey={shakeKey}
      error={error}
      busy={busy}
      submitLabel="Send the link"
      onSubmit={submit}
      links={[{ label: 'Back to sign in', onPress: onBack }]}
    >
      <Field
        value={email}
        onChangeText={setEmail}
        label="Email"
        autoCapitalize="none"
        autoCorrect={false}
        keyboardType="email-address"
        onSubmitEditing={submit}
      />
    </AuthLayout>
  );
}

const s = StyleSheet.create({
  sentTo: {
    fontSize: 14, fontWeight: '700', color: theme.color.ink, textAlign: 'center',
    marginBottom: theme.space(4),
  },
});
