import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { API_BASE, logout, restoreSession, type FeedPost, type Me } from '@/api';
import { LoginScreen } from '@/screens/LoginScreen';
import { SignupScreen } from '@/screens/SignupScreen';
import { ForgotScreen } from '@/screens/ForgotScreen';
import { FeedScreen } from '@/screens/FeedScreen';
import { ComposeScreen } from '@/screens/ComposeScreen';
import { theme } from '@/theme';

export default function App() {
  const [me, setMe] = useState<Me | null>(null);
  const [booting, setBooting] = useState(true);
  const [composing, setComposing] = useState(false);
  // 로그인 전 화면 전환 — 가입·비밀번호 찾기도 앱 안에서 처리한다
  const [authView, setAuthView] = useState<'login' | 'signup' | 'forgot'>('login');
  // 글을 올리면 이 값을 바꿔 피드를 다시 읽게 한다 (앱에서 쓴 글이 바로 목록에 보이도록)
  const [feedKey, setFeedKey] = useState(0);

  // 저장된 토큰이 아직 살아 있으면 로그인 화면을 건너뛴다
  useEffect(() => {
    let alive = true;
    restoreSession()
      .then((user) => { if (alive) setMe(user); })
      .finally(() => { if (alive) setBooting(false); });
    return () => { alive = false; };
  }, []);

  const signOut = useCallback(async () => {
    await logout();
    setMe(null);
  }, []);

  // 글 상세는 아직 앱 화면이 없다 — 우선 웹으로 열어 연동을 확인한다 (다음 단계에서 앱 화면으로 대체)
  const openPost = useCallback((post: FeedPost) => {
    void Linking.openURL(`${API_BASE}/p/${post.id}`);
  }, []);

  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <SafeAreaView style={s.root} edges={['top', 'bottom']}>
        {booting ? (
          <View style={s.center}><ActivityIndicator color={theme.color.ink} /></View>
        ) : !me ? (
          authView === 'signup' ? (
            <SignupScreen onDone={setMe} onBack={() => setAuthView('login')} />
          ) : authView === 'forgot' ? (
            <ForgotScreen onBack={() => setAuthView('login')} />
          ) : (
            <LoginScreen onDone={setMe} onSignup={() => setAuthView('signup')} onForgot={() => setAuthView('forgot')} />
          )
        ) : composing ? (
          <ComposeScreen
            onCancel={() => setComposing(false)}
            onPosted={() => { setComposing(false); setFeedKey((k) => k + 1); }}
          />
        ) : (
          <View style={s.root}>
            <View style={s.topBar}>
              <Text style={s.brand}>poz</Text>
              <Pressable onPress={signOut} hitSlop={8}>
                <Text style={s.signOut}>{me.handle} · sign out</Text>
              </Pressable>
            </View>
            <FeedScreen key={feedKey} onOpenPost={openPost} />
            {/* 앱의 본업 — 찍어서 올리기 */}
            <Pressable onPress={() => setComposing(true)} style={({ pressed }) => [s.fab, pressed && s.fabPressed]}>
              <Text style={s.fabText}>＋</Text>
            </Pressable>
          </View>
        )}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: theme.space(4),
    paddingVertical: theme.space(3),
    borderBottomWidth: 2,
    borderBottomColor: theme.color.ink,
    backgroundColor: theme.color.surface,
  },
  brand: { fontSize: 22, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.5 },
  signOut: { fontSize: 12.5, color: theme.color.inkSoft, fontWeight: '600' },
  fab: {
    position: 'absolute',
    right: theme.space(5),
    bottom: theme.space(6),
    width: 58,
    height: 58,
    borderRadius: theme.radius.pill,
    backgroundColor: theme.color.accent,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: theme.color.inkBlack,
    shadowOpacity: 0.25,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 6,
  },
  fabPressed: { backgroundColor: theme.color.accentDeep },
  fabText: { color: theme.color.paper, fontSize: 26, fontWeight: '700', lineHeight: 30 },
});
