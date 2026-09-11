import { useEffect, useState } from 'react';
import { ActivityIndicator, Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { API_BASE, logout, restoreSession, type FeedPost, type Me } from '@/api';
import { LoginScreen } from '@/screens/LoginScreen';
import { FeedScreen } from '@/screens/FeedScreen';
import { theme } from '@/theme';

export default function App() {
  const [me, setMe] = useState<Me | null>(null);
  const [booting, setBooting] = useState(true);

  // 저장된 토큰이 아직 살아 있으면 로그인 화면을 건너뛴다
  useEffect(() => {
    let alive = true;
    restoreSession()
      .then((user) => { if (alive) setMe(user); })
      .finally(() => { if (alive) setBooting(false); });
    return () => { alive = false; };
  }, []);

  async function signOut() {
    await logout();
    setMe(null);
  }

  // 글 상세는 아직 앱 화면이 없다 — 우선 웹으로 열어 연동을 확인한다 (다음 단계에서 앱 화면으로 대체)
  function openPost(post: FeedPost) {
    void Linking.openURL(`${API_BASE}/p/${post.id}`);
  }

  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <SafeAreaView style={s.root} edges={['top', 'bottom']}>
        {booting ? (
          <View style={s.center}><ActivityIndicator color={theme.color.ink} /></View>
        ) : !me ? (
          <LoginScreen onDone={setMe} />
        ) : (
          <View style={s.root}>
            <View style={s.topBar}>
              <Text style={s.brand}>poz</Text>
              <Pressable onPress={signOut} hitSlop={8}>
                <Text style={s.signOut}>{me.handle} · sign out</Text>
              </Pressable>
            </View>
            <FeedScreen onOpenPost={openPost} />
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
});
