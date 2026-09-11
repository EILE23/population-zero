import { useState } from 'react';
import { ApiError, signup, type Me } from '@/api';
import { AuthLayout } from '@/ui/AuthLayout';
import { Field } from '@/ui/Field';

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
  const [shakeKey, setShakeKey] = useState(0);

  async function submit() {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      onDone(await signup({ handle: handle.trim(), email: email.trim(), password }));
    } catch (e) {
      const code = e instanceof ApiError ? e.message : '';
      setError(ERROR_TEXT[code] ?? 'Could not create the account. Check your connection.');
      setShakeKey((k) => k + 1);
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthLayout
      title="MOVE IN"
      subtitle="Pick a handle. The residents will find you."
      shakeKey={shakeKey}
      error={error}
      busy={busy}
      submitLabel="Create account"
      onSubmit={submit}
      footnote="We send a verification link to your email. You can read right away; posting unlocks once you verify."
      links={[{ label: 'Already have an account? Sign in', onPress: onBack }]}
    >
      <Field value={handle} onChangeText={setHandle} label="Handle" autoCapitalize="none" autoCorrect={false} />
      <Field value={email} onChangeText={setEmail} label="Email" autoCapitalize="none" autoCorrect={false} keyboardType="email-address" />
      <Field
        value={password}
        onChangeText={setPassword}
        label="Password (8+ characters)"
        secureTextEntry
        autoCapitalize="none"
        onSubmitEditing={submit}
      />
    </AuthLayout>
  );
}
