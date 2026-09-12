import { subscribeSafetyChanges } from '@/api';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Alert, AppState, BackHandler, Linking, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { fetchThreads, logout, restoreSession, type DmThread, type FeedPost, type Me } from '@/api';
import { LoginScreen } from '@/screens/LoginScreen';
import { SignupScreen } from '@/screens/SignupScreen';
import { ForgotScreen } from '@/screens/ForgotScreen';
import { TodayScreen } from '@/screens/TodayScreen';
import { FeedScreen } from '@/screens/FeedScreen';
import { AlbumScreen } from '@/screens/AlbumScreen';
import { ComposeScreen } from '@/screens/ComposeScreen';
import { PhotoComposeScreen } from '@/screens/PhotoComposeScreen';
import { EditPostScreen } from '@/screens/EditPostScreen';
import { PostScreen } from '@/screens/PostScreen';
import { MeScreen } from '@/screens/MeScreen';
import { MessagesScreen } from '@/screens/MessagesScreen';
import { ProfileScreen } from '@/screens/ProfileScreen';
import { ChatScreen } from '@/screens/ChatScreen';
import { OpeningScreen } from '@/screens/OpeningScreen';
import { TabBar, TabPage, TAB_ORDER, type TabKey } from '@/ui/TabBar';
import { ToastProvider } from '@/ui/Toast';
import { theme } from '@/theme';

/** 탭 위에 겹쳐 뜨는 화면 — 상세·글쓰기·앨범 만들기·수정 */
type Overlay =
  | { kind: 'none' }
  | { kind: 'post'; id: number }
  | { kind: 'compose'; mode: 'write' | 'album' }
  | { kind: 'edit'; id: number }
  | { kind: 'messages' }
  | { kind: 'chat'; thread: DmThread }
  | { kind: 'profile'; handle: string };

export default function App() {
  const [me, setMe] = useState<Me | null>(null);
  const [booting, setBooting] = useState(true);
  const [bootError, setBootError] = useState(false);
  const [sessionRetry, setSessionRetry] = useState(0);
  const [opening, setOpening] = useState(true); // 오프닝 애니메이션이 끝날 때까지 덮어둔다
  const [tab, setTab] = useState<TabKey>('today');
  const [overlay, setOverlay] = useState<Overlay>({ kind: 'none' });
  // 로그인 전 화면 전환 — 가입·비밀번호 찾기도 앱 안에서 처리한다
  const [authView, setAuthView] = useState<'login' | 'signup' | 'forgot'>('login');
  // 글을 쓰거나 고치면 이 값을 올려 목록들을 다시 읽게 한다
  const [reloadKey, setReloadKey] = useState(0);

  // 어느 쪽에서 넘어왔는지 — 새 화면이 그 방향에서 미끄러져 들어오도록
  const prevTab = useRef<TabKey>('today');
  const direction = TAB_ORDER.indexOf(tab) >= TAB_ORDER.indexOf(prevTab.current) ? 1 : -1;
  const selectTab = useCallback((next: TabKey) => {
    setTab((current) => { prevTab.current = current; return next; });
  }, []);

  // 저장된 토큰이 아직 살아 있으면 로그인 화면을 건너뛴다
  useEffect(() => {
    let alive = true;
    restoreSession()
      .then((user) => { if (alive) setMe(user); })
      .catch(() => { if (alive) setBootError(true); })
      .finally(() => { if (alive) setBooting(false); });
    return () => { alive = false; };
  }, [sessionRetry]);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', state => {
      if (state !== 'active') return;
      void restoreSession().then(user => { setMe(user); setReloadKey(k => k + 1); }).catch(() => {});
    });
    return () => subscription.remove();
  }, []);

  useEffect(() => {
    const open = (url: string) => {
      try {
        const parsed = new URL(url);
        if (parsed.protocol !== 'poz:' && !(parsed.protocol === 'https:' && parsed.hostname === 'population.town')) return;
        const route = parsed.protocol === 'poz:' ? `/${parsed.hostname}${parsed.pathname}` : parsed.pathname;
        const match = route.match(/^\/p\/([1-9]\d*)\/?$/);
        if (match) setOverlay({ kind: 'post', id: Number(match[1]) });
      } catch { /* Ignore unsupported URLs. */ }
    };
    void Linking.getInitialURL().then(url => { if (url) open(url); });
    const subscription = Linking.addEventListener('url', event => open(event.url));
    return () => subscription.remove();
  }, []);

  useEffect(() => {
    const subscription = BackHandler.addEventListener('hardwareBackPress', () => {
      if (overlay.kind === 'compose' || overlay.kind === 'edit') {
        Alert.alert('Discard changes?', 'Your unpublished changes will be lost.', [
          { text: 'Keep writing', style: 'cancel' }, { text: 'Discard', style: 'destructive', onPress: () => setOverlay({ kind: 'none' }) },
        ]);
        return true;
      }
      if (overlay.kind !== 'none') { setOverlay({ kind: 'none' }); return true; }
      if (authView !== 'login') { setAuthView('login'); return true; }
      if (tab !== 'today') { setTab('today'); return true; }
      return false;
    });
    return () => subscription.remove();
  }, [overlay.kind, authView, tab]);

  const signOut = useCallback(async () => {
    await logout();
    setMe(null);
    setTab('today');
    setOverlay({ kind: 'none' });
  }, []);

  const openPost = useCallback((post: FeedPost) => setOverlay({ kind: 'post', id: post.id }), []);
  const openProfile = useCallback((handle: string) => setOverlay({ kind: 'profile', handle }), []);
  /**
   * 프로필에서 '쪽지'를 누르면 아직 대화가 없을 수 있다.
   * 그때는 빈 실을 열어 준다 — 첫 마디를 보내는 순간 서버가 진짜 열쇠로 묶는다.
   */
  const startChat = useCallback(async (handle: string) => {
    try {
      const threads = await fetchThreads();
      const found = threads.find((t) => t.other.handle === handle);
      if (found) { setOverlay({ kind: 'chat', thread: found }); return; }
    } catch { /* 목록을 못 읽어도 새 대화는 열 수 있다 */ }
    setOverlay({
      kind: 'chat',
      thread: {
        thread: '',
        preview: '',
        created_at: new Date().toISOString(),
        unread: 0,
        other: { kind: 'user', id: 0, handle, avatar: null },
      },
    });
  }, []);
  const openPostId = useCallback((id: number) => setOverlay({ kind: 'post', id }), []);
  const editPost = useCallback((post: FeedPost) => setOverlay({ kind: 'edit', id: post.id }), []);
  useEffect(() => subscribeSafetyChanges(() => { setOverlay({ kind: 'none' }); setReloadKey(n => n + 1); }), []);
  const closeOverlay = useCallback(() => setOverlay({ kind: 'none' }), []);
  const afterWrite = useCallback(() => {
    setOverlay({ kind: 'none' });
    setReloadKey((k) => k + 1);
  }, []);
  const onOpeningDone = useCallback(() => setOpening(false), []);

  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <SafeAreaView style={s.root} edges={['top', 'bottom']}>
        {bootError ? (
          <View style={s.root}>
            <Text>Could not reconnect. Your saved login is safe.</Text>
            <Pressable onPress={() => { setBootError(false); setBooting(true); setSessionRetry(k => k + 1); }}><Text>Try again</Text></Pressable>
          </View>
        ) : !me ? (
          authView === 'signup' ? (
            <SignupScreen onDone={setMe} onBack={() => setAuthView('login')} />
          ) : authView === 'forgot' ? (
            <ForgotScreen onBack={() => setAuthView('login')} />
          ) : (
            <LoginScreen onDone={setMe} onSignup={() => setAuthView('signup')} onForgot={() => setAuthView('forgot')} />
          )
        ) : (
          <View style={s.root}>
            {/* 네 화면 모두 살려둔 채 감춘다 — 탭을 오갈 때 스크롤 위치와 목록이 유지되도록 */}
            <TabPage active={tab === 'today'} direction={direction}>
              <TodayScreen />
            </TabPage>
            <TabPage active={tab === 'community'} direction={direction}>
              <FeedScreen
                me={me}
                reloadKey={reloadKey}
                onOpenPost={openPost}
                onOpenPostId={openPostId}
                onEditPost={editPost}
                onWrite={() => setOverlay({ kind: 'compose', mode: 'write' })}
              />
            </TabPage>
            <TabPage active={tab === 'album'} direction={direction}>
              <AlbumScreen
                reloadKey={reloadKey}
                onOpenPost={openPostId}
                onCompose={() => setOverlay({ kind: 'compose', mode: 'album' })}
              />
            </TabPage>
            <TabPage active={tab === 'messages'} direction={direction}>
              <MessagesScreen active={tab === 'messages' && overlay.kind === 'none'} onOpen={(thread) => setOverlay({ kind: 'chat', thread })} />
            </TabPage>
            <TabPage active={tab === 'me'} direction={direction}>
              <MeScreen
                me={me}
                reloadKey={reloadKey}
                onSignOut={signOut}
                onOpenPost={openPostId}
                onOpenMessages={() => selectTab('messages')}
              />
            </TabPage>

            <TabBar active={tab} onSelect={selectTab} />

            {overlay.kind === 'post' ? (
              <View style={s.overlay}>
                <PostScreen
                  postId={overlay.id}
                  onBack={closeOverlay}
                  onEdit={(detail) => setOverlay({ kind: 'edit', id: detail.post.id })}
                  onOpenProfile={openProfile}
                />
              </View>
            ) : overlay.kind === 'compose' ? (
              <View style={s.overlay}>
                {/* 앨범과 글쓰기는 올리는 화면 자체가 다르다 */}
                {overlay.mode === 'album'
                  ? <PhotoComposeScreen onCancel={closeOverlay} onPosted={afterWrite} />
                  : <ComposeScreen onCancel={closeOverlay} onPosted={afterWrite} />}
              </View>
            ) : overlay.kind === 'edit' ? (
              <View style={s.overlay}>
                <EditPostScreen postId={overlay.id} onCancel={closeOverlay} onSaved={afterWrite} />
              </View>
            ) : overlay.kind === 'profile' ? (
              <View style={s.overlay}>
                <ProfileScreen
                  handle={overlay.handle}
                  onBack={closeOverlay}
                  onOpenPost={openPostId}
                  onMessage={(h) => void startChat(h)}
                />
              </View>
            ) : overlay.kind === 'chat' ? (
              <View style={s.overlay}>
                <ChatScreen
                  thread={overlay.thread.thread}
                  other={overlay.thread.other}
                  onBack={closeOverlay}
                />
              </View>
            ) : null}
          </View>
        )}

        {/* 켜자마자 보이는 오프닝 — 세션 복구가 끝나면 로고가 커지며 걷힌다 */}
        {opening ? <OpeningScreen ready={!booting} onDone={onOpeningDone} /> : null}
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  overlay: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: theme.color.paper,
  },
});
