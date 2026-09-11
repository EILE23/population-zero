import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, RefreshControl, ScrollView,
  StyleSheet, Text, View,
} from 'react-native';
import { fetchThreads, type DmThread } from '@/api';
import { Avatar } from '@/ui/Avatar';
import { EmptyState } from '@/ui/EmptyState';
import { timeAgo } from '@/ui/cards';
import { TAB_BAR_HEIGHT } from '@/ui/TabBar';
import { theme } from '@/theme';

/**
 * 대화 내역 — 지금까지 누구와 무슨 말을 했는지.
 * 웹에서는 같은 데이터가 쪽지함으로 보인다. 주민(AI)과의 대화도 여기 같이 쌓인다.
 */
export function MessagesScreen({ onOpen }: {
  onOpen: (thread: DmThread) => void;
}) {
  const [threads, setThreads] = useState<DmThread[] | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 처음 열기 — 화면을 닫고 응답이 와도 아무것도 건드리지 않게 가드를 둔다
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const list = await fetchThreads();
        if (!alive) return;
        setThreads(list);
        setError(null);
      } catch {
        if (!alive) return;
        setThreads([]);
        setError('Could not open your messages.');
      }
    })();
    return () => { alive = false; };
  }, []);

  const load = useCallback(async () => {
    try {
      setThreads(await fetchThreads());
      setError(null);
    } catch {
      setThreads([]);
      setError('Could not open your messages.');
    }
  }, []);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  return (
    <View style={s.root}>
      <View style={s.header}>
        <Text style={s.heading}>Chat</Text>
      </View>

      {threads == null ? (
        <View style={s.center}><ActivityIndicator color={theme.color.accent} /></View>
      ) : threads.length === 0 ? (
        // 아무것도 없을 때는 목록의 첫 줄이 아니라 화면 한가운데에 — 앨범과 같은 자리
        <View style={s.emptyRoot}>
          <EmptyState
            title={error ? 'Could not open your messages' : 'No conversations yet'}
            body={error ?? 'Open a post, tap the author, and say something. Residents answer on the next patrol.'}
            actionLabel={error ? 'Try again' : undefined}
            onAction={error ? refresh : undefined}
          />
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={s.content}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.color.accent} />}
        >
            <View style={s.list}>
              {threads.map((t, i) => (
                <Pressable
                  key={t.thread}
                  onPress={() => onOpen(t)}
                  style={({ pressed }) => [s.row, i > 0 && s.divider, pressed && s.rowPressed]}
                >
                  <Avatar handle={t.other.handle} size={42} isHuman={t.other.kind === 'user'} src={t.other.avatar} />
                  <View style={s.rowText}>
                    <View style={s.rowHead}>
                      <Text style={s.handle} numberOfLines={1}>{t.other.handle}</Text>
                      {t.other.kind === 'resident' ? <Text style={s.tag}>AI</Text> : null}
                      <View style={s.spacer} />
                      <Text style={s.when}>{timeAgo(t.created_at)}</Text>
                    </View>
                    <Text style={[s.preview, t.unread > 0 && s.previewUnread]} numberOfLines={1}>
                      {t.preview || 'Photo'}
                    </Text>
                  </View>
                  {t.unread > 0 ? (
                    <View style={s.badge}>
                      <Text style={s.badgeText}>{t.unread > 99 ? '99+' : t.unread}</Text>
                    </View>
                  ) : null}
                </Pressable>
              ))}
            </View>
        </ScrollView>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.color.surface },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  emptyRoot: { flex: 1, justifyContent: 'center' },
  header: { paddingHorizontal: theme.space(4), paddingTop: theme.space(4), paddingBottom: theme.space(1) },
  heading: { fontSize: 21, fontWeight: '800', color: theme.color.ink, letterSpacing: -0.4 },
  content: { padding: theme.space(4), paddingBottom: TAB_BAR_HEIGHT + theme.space(6) },
  list: {
    backgroundColor: theme.color.paper, borderRadius: theme.radius.lg,
    borderWidth: 1, borderColor: theme.color.hairline, overflow: 'hidden',
  },
  row: {
    flexDirection: 'row', alignItems: 'center', gap: theme.space(3),
    paddingHorizontal: theme.space(4), paddingVertical: theme.space(3.5),
  },
  divider: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: theme.color.hairline },
  rowPressed: { backgroundColor: theme.color.surfaceDeep },
  rowText: { flex: 1, minWidth: 0 },
  rowHead: { flexDirection: 'row', alignItems: 'center', gap: theme.space(1.5) },
  handle: { fontSize: 14, fontWeight: '700', color: theme.color.ink, flexShrink: 1 },
  tag: { fontSize: 8.5, letterSpacing: 0.6, fontWeight: '800', color: theme.color.accent },
  spacer: { flex: 1 },
  when: { fontSize: 10.5, color: theme.color.inkFaint },
  preview: { fontSize: 12.5, color: theme.color.inkSoft, marginTop: 3 },
  previewUnread: { color: theme.color.ink, fontWeight: '600' },
  badge: {
    minWidth: 18, height: 18, borderRadius: 9, paddingHorizontal: 5,
    backgroundColor: theme.color.accent, alignItems: 'center', justifyContent: 'center',
  },
  badgeText: { color: theme.color.paper, fontSize: 10, fontWeight: '800' },
});
