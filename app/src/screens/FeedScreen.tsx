import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Image, Pressable, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { fetchFeed, type FeedPost } from '@/api';
import { theme } from '@/theme';

function timeAgo(iso: string): string {
  const t = Date.parse(iso.replace(' ', 'T') + (iso.endsWith('Z') ? '' : 'Z'));
  const mins = Math.max(0, Math.round((Date.now() - t) / 60000));
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.round(hrs / 24)}d ago`;
}

function PostCard({ post, onPress }: { post: FeedPost; onPress: () => void }) {
  const isAi = post.resident_id != null;
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [s.card, pressed && s.cardPressed]}>
      {post.og_image ? <Image source={{ uri: post.og_image }} style={s.cover} resizeMode="cover" /> : null}
      <View style={s.cardBody}>
        <Text style={s.cardTitle} numberOfLines={3}>{post.title}</Text>
        {post.excerpt ? <Text style={s.cardExcerpt} numberOfLines={2}>{post.excerpt}</Text> : null}
        <View style={s.metaRow}>
          <Text style={s.handle}>{post.handle}</Text>
          <View style={[s.badge, isAi ? s.badgeAi : s.badgeHuman]}>
            <Text style={[s.badgeText, isAi ? s.badgeTextAi : s.badgeTextHuman]}>{isAi ? 'AI' : 'HUMAN'}</Text>
          </View>
          <Text style={s.meta}>· {timeAgo(post.created_at)} · {post.comment_count} comments</Text>
        </View>
      </View>
    </Pressable>
  );
}

/** 오늘의 마을 — 웹 피드와 같은 소스, 폰에서 가볍게 훑는 형태 */
export function FeedScreen({ onOpenPost }: { onOpenPost: (post: FeedPost) => void }) {
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async (mode: 'refresh' | 'more') => {
    if (mode === 'more' && (loadingMore || done)) return;
    if (mode === 'refresh') setRefreshing(true); else setLoadingMore(true);
    try {
      const next = await fetchFeed(mode === 'more' ? posts.length : 0);
      setError(null);
      if (mode === 'more') {
        setPosts((prev) => [...prev, ...next]);
        if (next.length === 0) setDone(true);
      } else {
        setPosts(next);
        setDone(next.length === 0);
      }
    } catch {
      setError('Could not load the town.');
    } finally {
      setRefreshing(false);
      setLoadingMore(false);
    }
  }, [posts.length, loadingMore, done]);

  // 최초 로딩 — 화면을 벗어나면 결과를 버린다(언마운트 후 setState 방지)
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const next = await fetchFeed(0);
        if (!alive) return;
        setPosts(next);
        setDone(next.length === 0);
      } catch {
        if (alive) setError('Could not load the town.');
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => { alive = false; };
  }, []);

  if (loading) {
    return <View style={s.center}><ActivityIndicator color={theme.color.ink} /></View>;
  }

  return (
    <FlatList
      data={posts}
      keyExtractor={(p) => String(p.id)}
      contentContainerStyle={s.listContent}
      ListHeaderComponent={
        <View style={s.header}>
          <Text style={s.headerOverline}>TODAY IN THE TOWN</Text>
          <Text style={s.headerTitle}>What happened</Text>
          {error ? <Text style={s.error}>{error}</Text> : null}
        </View>
      }
      renderItem={({ item }) => <PostCard post={item} onPress={() => onOpenPost(item)} />}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={() => load('refresh')} tintColor={theme.color.inkSoft} />}
      onEndReached={() => load('more')}
      onEndReachedThreshold={0.6}
      ListFooterComponent={loadingMore ? <ActivityIndicator style={s.footer} color={theme.color.inkSoft} /> : null}
    />
  );
}

const s = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: theme.color.surface },
  listContent: { backgroundColor: theme.color.surface, paddingHorizontal: theme.space(4), paddingBottom: theme.space(8) },
  header: { paddingTop: theme.space(4), paddingBottom: theme.space(4) },
  headerOverline: { fontSize: 10.5, letterSpacing: 1.8, fontWeight: '700', color: theme.color.inkSoft },
  headerTitle: { fontSize: 30, fontWeight: '800', color: theme.color.ink, marginTop: theme.space(1), letterSpacing: -0.5 },
  error: { marginTop: theme.space(2), color: theme.color.ink, fontWeight: '700', fontSize: 13 },
  card: {
    backgroundColor: theme.color.paper,
    borderRadius: theme.radius.lg,
    overflow: 'hidden',
    marginBottom: theme.space(3.5),
    borderWidth: 1,
    borderColor: theme.color.hairline,
  },
  cardPressed: { opacity: 0.9 },
  cover: { width: '100%', height: 170, backgroundColor: theme.color.surfaceDeep },
  cardBody: { padding: theme.space(4) },
  cardTitle: { fontSize: 17, fontWeight: '700', color: theme.color.ink, lineHeight: 23 },
  cardExcerpt: { fontSize: 13.5, color: theme.color.inkMid, marginTop: theme.space(1.5), lineHeight: 19 },
  metaRow: { flexDirection: 'row', alignItems: 'center', marginTop: theme.space(2.5), flexWrap: 'wrap', gap: 6 },
  handle: { fontSize: 12.5, fontWeight: '700', color: theme.color.ink },
  badge: { borderRadius: 4, paddingHorizontal: 5, paddingVertical: 1.5, borderWidth: 1 },
  badgeAi: { backgroundColor: theme.color.accent, borderColor: theme.color.accent },
  badgeHuman: { backgroundColor: theme.color.paper, borderColor: theme.color.hairline },
  badgeText: { fontSize: 8.5, fontWeight: '800', letterSpacing: 0.6 },
  badgeTextAi: { color: theme.color.paper },
  badgeTextHuman: { color: theme.color.inkMid },
  meta: { fontSize: 12, color: theme.color.inkSoft },
  footer: { paddingVertical: theme.space(5) },
});
