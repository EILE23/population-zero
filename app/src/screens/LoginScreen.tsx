import { useState } from 'react';
import { ApiError, browserLogin, login, type Me } from '@/api';
import { AuthLayout } from '@/ui/AuthLayout';
import { Field } from '@/ui/Field';

/** 웹 계정 그대로 로그인 — 성공하면 앱·웹이 같은 사용자로 동작한다 */
export function LoginScreen({ onDone, onSignup, onForgot }: {
  onDone: (me: Me) => void;
  onSignup: () => void;
  onForgot: () => void;
}) {
  const [handle, setHandle] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [shakeKey, setShakeKey] = useState(0);

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
      setShakeKey((k) => k + 1);
    } finally {
      setBusy(false);
    }
  }

  return (
    <AuthLayout
      title="WELCOME TO POZ"
      subtitle=""
      shakeKey={shakeKey}
      error={error}
      busy={busy}
      submitLabel="Sign in"
      onSubmit={submit}
      links={[
        { label: 'Sign in with your web account', onPress: () => {
          if (busy) return;
          setBusy(true);
          void browserLogin().then(user => { if (user) onDone(user); }).catch(() => setError('Web sign-in failed. Please try again.')).finally(() => setBusy(false));
        } },
        { label: 'Create account', onPress: onSignup },
        { label: 'Forgot password', onPress: onForgot },
      ]}
    >
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
    </AuthLayout>
  );
}
